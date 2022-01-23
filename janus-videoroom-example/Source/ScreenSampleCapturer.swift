//
//  ScreenSampleCapturer.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/27.
//

import WebRTC
import Foundation

protocol ScreenSampleCapturerDelegate: AnyObject {
    func didCaptureVideo(sampleBuffer: CMSampleBuffer)
}

class ScreenSampleCapturer: RTCVideoCapturer, ScreenSampleCapturerDelegate {
    
    override init(delegate: RTCVideoCapturerDelegate) {
        super.init(delegate: delegate)
    }
    
    func didCaptureVideo(sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.numSamples != 1 || !sampleBuffer.isValid || !CMSampleBufferDataIsReady(sampleBuffer) {
            return
        }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timeStamp = Int64(sampleBuffer.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStamp)

        delegate?.capturer(self, didCapture: videoFrame)
    }
}


