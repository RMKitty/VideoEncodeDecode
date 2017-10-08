//
//  H264encoder.h
//  H264Encode
//
//  Created by Kitty on 2017/5/3.
//  Copyright © 2017年 RM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@interface H264encoder : NSObject

- (void)prepareEncodeWithWidth: (int)width height: (int)height framerate:(int)fps bitrate:(int)bt;
- (void)prepareEncodeWithWidth: (int)width height: (int)height;

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;

- (void)stopSessionEncode;
@end
