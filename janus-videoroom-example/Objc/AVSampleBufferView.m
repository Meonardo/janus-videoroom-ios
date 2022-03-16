//
//  AVSampleBufferView.m
//  janus-videoroom-example
//
//  Created by Meonardo on 2022/3/16.
//

#import "AVSampleBufferView.h"
#import "WebRTC/RTCVideoFrame.h"
#import "WebRTC/RTCCVPixelBuffer.h"

@interface RTC_OBJC_TYPE (AVSampleBufferView) ()

@property (atomic, strong) RTC_OBJC_TYPE(RTCVideoFrame) *videoFrame;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSUInteger lastDrawnFrameTimeStampNs;

@end

@implementation RTC_OBJC_TYPE (AVSampleBufferView)

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self config];
    }
    return self;
}

- (void)destroy {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

#pragma mark - Configs

- (void)config {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onRender:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)onRender:(CADisplayLink *)sender {
    if (self.videoFrame == nil || self.window == nil)
        return;
    // Don't render unless video frame have changed
    if (_lastDrawnFrameTimeStampNs == self.videoFrame.timeStampNs)
        return;
    if (CGSizeEqualToSize(self.bounds.size, CGSizeZero))
        return;
    
    RTC_OBJC_TYPE(RTCVideoFrame) *frame = self.videoFrame;
    if ([frame.buffer isKindOfClass:[RTC_OBJC_TYPE(RTCCVPixelBuffer) class]]) {
        // NV12 format
        RTC_OBJC_TYPE(RTCCVPixelBuffer) *buffer = (RTC_OBJC_TYPE(RTCCVPixelBuffer) *)frame.buffer;
        CVPixelBufferRef pixelBuffer = buffer.pixelBuffer;
        [self displayPixelBuffer:pixelBuffer];
        
        _lastDrawnFrameTimeStampNs = self.videoFrame.timeStampNs;
    } else {
        // RTCI420Buffer
        // TODO: convert the buffer to CVPixelBufferRef
        // https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/objc/unittests/frame_buffer_helpers.mm#69
        // or
        // https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/objc/components/video_codec/RTCVideoEncoderH264.mm#95
    }
}

+ (Class)layerClass {
    return [AVSampleBufferDisplayLayer class];
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    return (AVSampleBufferDisplayLayer *)self.layer;
}

- (void)setGravity:(AVLayerVideoGravity)gravity {
    if ([NSThread isMainThread]) {
        self.displayLayer.videoGravity = gravity;
        
        CGRect bounds = self.displayLayer.bounds;
        self.displayLayer.bounds = CGRectZero;
        self.displayLayer.bounds = bounds;
        
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.displayLayer.videoGravity = gravity;
            CGRect bounds = self.displayLayer.bounds;
            self.displayLayer.bounds = CGRectZero;
            self.displayLayer.bounds = bounds;
        });
    }
}

#pragma mark - RTCVideoRenderer

- (void)renderFrame:(RTC_OBJC_TYPE(RTCVideoFrame) *)frame {
    if (frame == nil) {
        return;
    }
    self.videoFrame = frame;
}

- (void)setSize:(CGSize)size {
    __weak RTC_OBJC_TYPE(AVSampleBufferView) *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        RTC_OBJC_TYPE(AVSampleBufferView) *strongSelf = weakSelf;
        [strongSelf.delegate videoView:strongSelf didChangeVideoSize:size];
    });
}

#pragma mark - Rendering

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }
    
    CVPixelBufferRetain(pixelBuffer);
    CMSampleBufferRef sampleBuffer = [self createSampleBufferWithPixelBuffer:pixelBuffer];
    CVPixelBufferRelease(pixelBuffer);
    
    if (!sampleBuffer) {
        return;
    }
    
    [self displaySampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
}

- (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return NULL;
    }
    
    // NOT set any timing info currently.
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    if (result != 0) {
        return NULL;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    if (result != 0) {
        return NULL;
    }
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    
    return sampleBuffer;
}

- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (sampleBuffer == NULL) {
        return;
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [self.displayLayer flush];
        }
        
        [self.displayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

@end
