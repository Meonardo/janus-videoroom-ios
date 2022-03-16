//
//  AVSampleBufferView.h
//  janus-videoroom-example
//
//  Created by Meonardo on 2022/3/16.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "WebRTC/RTCVideoRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface RTC_OBJC_TYPE (AVSampleBufferView) : UIView <RTC_OBJC_TYPE(RTCVideoRenderer)>

@property (nonatomic, weak) id<RTC_OBJC_TYPE(RTCVideoViewDelegate)> delegate;
@property (nonatomic, copy) AVLayerVideoGravity gravity;

// invalidate CADisplayLink
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
