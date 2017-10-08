//
//  VideoCapture.h
//  H264Encode
//
//  Created by Kitty on 2017/5/4.
//  Copyright © 2017年 RM. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject

- (void)startCapturing:(UIView *)preView;
- (void)stopCapturing;

@end
