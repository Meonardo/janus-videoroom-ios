
import Foundation
import CoreVideo

/// 16 bytes for header
let headerLength = 16
/// MTU chunk size
let chunkSize = 4096

struct PixelDataST {
    private let space: UInt16 = 0
    /// header size 20 bytes
    let length = 20
    
    /// body length
    var bodyLength: UInt32
    /// seq number
    var seq: UInt32
    var yLength: UInt32
    var cbcrLength: UInt32
    /// start code or end code
    var code: [UInt8]
    
    var isStart: Bool {
        return code[0] == 83 && code[1] == 84
    }
    
    var isEnd: Bool {
        return code[0] == 69 && code[1] == 68
    }
    
    static func startData(bodyLength: UInt32, seq: UInt32, yLength: UInt32, cbcrLength: UInt32) -> PixelDataST {
        return PixelDataST(
            bodyLength: bodyLength,
            seq: seq,
            yLength: yLength,
            cbcrLength: cbcrLength,
            code: [83, 84]
        )
    }
    
    static func endData(bodyLength: UInt32, seq: UInt32, yLength: UInt32, cbcrLength: UInt32) -> PixelDataST {
        return PixelDataST(
            bodyLength: bodyLength,
            seq: seq,
            yLength: yLength,
            cbcrLength: cbcrLength,
            code: [69, 68]
        )
    }
    
    var representData: Data {
        let buffer = ByteBuffer(size: length)
        
        buffer.put(UInt32(bodyLength))
        buffer.put(UInt32(yLength)).put(UInt32(cbcrLength))
        buffer.put(seq)
        buffer.put(space)
        buffer.append(code)

        return buffer.data
    }
    
    static func parse(from data: Data) -> PixelDataST? {
        let buffer = ByteBuffer(data: data)
        
        let c1 = buffer.get(18)
        let c2 = buffer.get(19)
        
        let code = [c1, c2]
        
        let bodyLength = buffer.getUInt32(0)
        let yLength = buffer.getUInt32(4)
        let cbcrLength = buffer.getUInt32(8)
        let seq = buffer.getUInt32(12)
        
        return PixelDataST(
            bodyLength: bodyLength,
            seq: seq,
            yLength: yLength,
            cbcrLength: cbcrLength,
            code: code
        )
    }
}

func getData(from pixelBuffer: CVPixelBuffer) -> (Data, Int, Int) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
//    let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
//    let width = CVPixelBufferGetWidth(pixelBuffer)
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
    
    return (data, yLength, cbcrLength)
}

func constructorPacket(body: Data, seq: UInt32, yLength: UInt32, cbcrLength: UInt32) -> Data {
    let total = body.count + headerLength
    let buffer = ByteBuffer(size: total)
    
    buffer.put(UInt32(total))
    buffer.put(UInt32(yLength)).put(UInt32(cbcrLength))
    buffer.put(seq)
    
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
//    data.withUnsafeBytes{ UnsafeRawPointer($0) }
    let srcPtr = data.withUnsafeBytes({ UnsafeRawPointer($0) })

    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    memcpy(yBaseAddress, srcPtr, yLength)
    let cbcrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    memcpy(cbcrBaseAddress, srcPtr.advanced(by: yLength), cbcrLength)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

    return pixelBuffer
}

func getYLength(from data: Data) -> UInt32 {
    guard data.count >= headerLength else { return 0 }
    let index = 8
    let d = data[index..<index+4]
    let v = d.reduce(0) { v, byte in
        return v << 8 | UInt32(byte)
    }
    return v
}

func getCbcrLength(from data: Data) -> UInt32 {
    guard data.count >= headerLength else { return 0 }
    let index = 12
    let d = data[index..<index+4]
    let v = d.reduce(0) { v, byte in
        return v << 8 | UInt32(byte)
    }
    return v
}

/// 正文消息内容
/// - Parameter data: 原始数据
/// - Returns: 消息体数据
func messageBody(raw data: Data) -> Data {
    guard data.count >= 16 else { return data }
    return data.suffix(from: headerLength)
}
