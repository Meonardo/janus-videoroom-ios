//
//  ScreenSampleCapturer.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/27.
//

import WebRTC
import CocoaAsyncSocket
import Foundation

protocol ScreenSampleCapturerDelegate: AnyObject {
    func didCaptureVideo(sampleBuffer: CMSampleBuffer)
}

private let headerLength = 16

class ScreenSampleCapturer: RTCVideoCapturer, ScreenSampleCapturerDelegate {
    
    private let socket = OutSocket()
    
    override init(delegate: RTCVideoCapturerDelegate) {
        super.init(delegate: delegate)
    }
    
    func didCaptureVideo(sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.numSamples != 1 || !sampleBuffer.isValid || !CMSampleBufferDataIsReady(sampleBuffer) {
            return
        }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        let tuple = getData(from: pixelBuffer)
        let data = tuple.0
//        let type = tuple.1
        let width = tuple.2
        let height = tuple.3
        
        let packetData = constructorPacket(body: data, width: width, height: height)
        socket.send(data: packetData)
        
//        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
//        let timeStamp = Int64(sampleBuffer.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
//        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStamp)
//
//        delegate?.capturer(self, didCapture: videoFrame)
    }
}

private let IP = "127.0.0.1"
private let PORT: UInt16 = 55555

func getData(from pixelBuffer: CVPixelBuffer) -> (Data, OSType, Int, Int) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    var data = Data()
    let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let yLength = yBytesPerRow * height
    data.append(Data(bytes: yBaseAddress!, count: yLength))

    let cbcrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    let cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
    let cbcrLength = cbcrBytesPerRow * height / 2
    data.append(Data(bytes: cbcrBaseAddress!, count: cbcrLength))

    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return (data, pixelFormatType, width, height)
}

func constructorPacket(body: Data, width: Int, height: Int) -> Data {
    let bodyLength = body.count
    let total = bodyLength + headerLength
    let space: UInt16 = 0
    
    let buffer = ByteBuffer(size: total)
    
    buffer.put(UInt32(total))
    
    buffer.put(space).put(space)
    buffer.put(UInt16(width)).put(UInt16(height))
    buffer.put(space).put(space)
    
    buffer.append(body)

    return buffer.data
}

func getPixelBuffer(from data: Data, pixelBufferPool: CVPixelBufferPool, yLength: Int, cbcrLength: Int) -> CVPixelBuffer? {
    guard data.count == yLength + cbcrLength else { return nil }
    
    var _pixelBuffer: CVPixelBuffer?
    //用CVPixelBufferPoolCreatePixelBuffer创建CVPixelBuffer会更快一些
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &_pixelBuffer)
    guard status == kCVReturnSuccess, let pixelBuffer = _pixelBuffer else {
        print("CVPixelBufferPoolCreatePixelBuffer error")
        return nil
    }
    
    //把data转换为指针，用指针进行memcpy操作，比用subdata快上百倍
    let srcPtr = data.withUnsafeBytes({ UnsafeRawPointer($0) })

    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    memcpy(yBaseAddress, srcPtr, yLength)
    let cbcrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    memcpy(cbcrBaseAddress, srcPtr.advanced(by: yLength), cbcrLength)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

    return pixelBuffer
}

// Recv
class InSocket: NSObject, GCDAsyncUdpSocketDelegate {
    
    var socket: GCDAsyncUdpSocket!
    
    override init() {
        super.init()
        config()
    }
    
    func config() {
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: nil)
        do {
            try socket.bind(toPort: PORT)
        } catch {
            print("")
        }
        
        do {
            try socket.beginReceiving()
        } catch {
            print("beginReceiving not proceed")
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        print("incoming message: \(data)");
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {}
    
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {}
}

// Send
class OutSocket: NSObject, GCDAsyncUdpSocketDelegate {
    
    var socket: GCDAsyncUdpSocket!
    
    override init() {
        super.init()
        config()
    }
    
    func config() {
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: nil)
        do {
            try socket.bind(toPort: 0)
        } catch {
            print("")
        }
    }
    
    func send(data: Data) {
        socket.send(data, toHost: IP, port: PORT, withTimeout: -1, tag: 0)
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        print("didConnectToAddress");
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        if let error = error {
            print("didNotConnect \(error.localizedDescription)")
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
          print("didNotSendDataWithTag")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print("didSendDataWithTag")
    }
}
