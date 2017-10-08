//
//  VideoCapture.m
//  H264Encode
//
//  Created by Kitty on 2017/5/4.
//  Copyright © 2017年 RM. All rights reserved.
//

#import "VideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import "H264encoder.h"

@interface VideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic,weak) AVCaptureSession * captureSession;
//@property (nonatomic,weak) AVCaptureVideoPreviewLayer * previewLayer;
@property (nonatomic, strong) H264encoder *encoder;


@end

@implementation VideoCapture

- (void)initVideoCapture: (UIView *)preView {
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        session.sessionPreset = AVCaptureSessionPreset640x480;

    } else {
        session.sessionPreset = AVCaptureSessionPresetPhoto;
    }
    self.captureSession = session;
    // 设置视频输入
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *inputDevice = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
//    if ([session canAddInput:inputDevice]) {
        [session addInput:inputDevice];
//    }
    //设置视频输出
    AVCaptureVideoDataOutput * outputData = [[AVCaptureVideoDataOutput alloc] init];
    /* ONLY support pixel format : 420v, 420f, BGRA */
    outputData.videoSettings = [NSDictionary dictionaryWithObject:
                                [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [outputData setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    
    if ([session canAddOutput:outputData]) {
        [session addOutput:outputData];
    }
    // 设置采集图像的方向,如果不设置，采集回来的图形会是旋转90度的
    // 注意: 设置方向, 必须在将output添加到session之后
    AVCaptureConnection *connection = [outputData connectionWithMediaType:AVMediaTypeVideo];
    if ([connection isVideoOrientationSupported]) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        NSLog(@"not support");
    }
//    [session commitConfiguration];
    // 添加预览层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    layer.frame = preView.bounds;
    [preView.layer insertSublayer:layer above:0];
    
}

- (void)startCapturing:(UIView *)preView {
    // =============================== 准备编码 =================================
    self.encoder = [[H264encoder alloc] init];
    [self.encoder prepareEncodeWithWidth:480 height:640];

    [self initVideoCapture:preView];
    [self.captureSession startRunning];
    
}
- (void)stopCapturing
{
    //    [self.previewLayer removeFromSuperlayer];
    [self.captureSession stopRunning];
    [self.encoder stopSessionEncode];
}
#pragma AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    [self.encoder encodeFrame:sampleBuffer];
}
// 如果出现丢帧
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
}


@end
