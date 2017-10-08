//
//  H264encoder.m
//  H264Encode
//
//  Created by Kitty on 2017/5/3.
//  Copyright © 2017年 RM. All rights reserved.
//

#import "H264encoder.h"
#import <VideoToolbox/VideoToolbox.h>

#define VIDEONAME @"/v_encode.h264"

@interface H264encoder()
{
    int     _spsppsFound;
}

@property (nonatomic,assign) VTCompressionSessionRef compressionSession;
/** 帧的位置 */
@property (nonatomic,assign) int frameIndex;

/** 文件写入对象 */
@property (nonatomic,strong) NSFileHandle *fileHandle;

@end

@implementation H264encoder

- (void)prepareEncodeWithWidth: (int)width height: (int)height {
    
    [self prepareEncodeWithWidth:width height:height framerate:24 bitrate:640*1024];
}
/*!
 @method prepareEncodeWithWidth: height: framerate: bitrate:
 @abstract VT PrepareToEncodeFrames
 @param	width
 The width of frames, in pixels.
 If the video encoder cannot support the provided width and height it may change them.
 @param	height
 The height of frames in pixels.

 */

- (void)prepareEncodeWithWidth: (int)width height: (int)height framerate:(int)fps bitrate:(int)bt
{
    
    NSFileManager *filemanager = [NSFileManager defaultManager];
    NSString *documentFile = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *filePath = [documentFile stringByAppendingString:VIDEONAME];
    if ([filemanager fileExistsAtPath:filePath]) {
        [filemanager removeItemAtPath:filePath error:nil];
    }
    [filemanager createFileAtPath:filePath contents:nil attributes:nil];
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    /** @discription c FILE
     fopen([filePath UTF8String], "wb");
     
     */
    
    OSStatus status;
    // 设置默认从0帧开始
    self.frameIndex = 0;
    // 1> 参数一: CFAllocatorRef用于CoreFoundation分配内存的模式 NULL使用默认的分配方式
    // 2> 参数二: 编码出来视频的宽度 width
    // 3> 参数三: 编码出来视频的高度 height
    // 4> 参数四: 编码的标准 : H.264/AVC
    // 5> 参数五/六/七 : NULL
    // 6> 参数八: 编码成功后的回调函数
    // 7> 参数九: 可以传递到回调函数中参数, self : 将当前对象传入
    VTCompressionOutputCallback cb = didCompressionCallback;
    status = VTCompressionSessionCreate(kCFAllocatorDefault, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, cb, (__bridge void * _Nullable)(self), &_compressionSession);
    if (status != noErr) {
        NSLog(@"VTCompressionSessionCreate failed. ret=%d", (int)status);
//        return -1;
    }
    // 设置实时编码输出，降低编码延迟
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    NSLog(@"set realtime  return: %d", (int)status);
    
    // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    // 设置帧率，只用于初始化session，不是实际FPS default 24
    fps = @(fps) == NULL ? 24 : fps;
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nonnull)@(fps));
    NSLog(@"set framerate return: %d", (int)status);

    // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊 default 1500000/s
    bt = @(bt) == NULL ? 1500000 : bt;
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate,(__bridge CFTypeRef _Nonnull) @(bt)); // bite
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nonnull)(@[@(bt/8) ,@1])); // byte
    NSLog(@"set bitrate   return: %d", (int)status);
    
    // 设置关键帧间隔，即gop size
    status = VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nonnull)(@(fps)));
    
    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    NSLog(@"start encode  return: %d", (int)status);

    
}
// 编码一帧图像, 最好在异步线程里面 防止阻塞
- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer {
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
//    __weak typeof(self)weakSelf = self;
    dispatch_sync(queue, ^{
        // 1.将CMSampleBufferRef转成CVImageBufferRef
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        //  参数一: compressionSession
        //  参数二: 需要将CMSampleBufferRef转成CVImageBufferRef
        //  参数三: PTS(presentationTimeStamp)/DTS(DecodeTimeStamp)
        //  参数四: kCMTimeInvalid
        //  参数五: 是在回调函数中第二个参数
        //  参数六: 是在回调函数中第四个参数
        
        //pts,必须设置，否则会导致编码出来的数据非常大  1000
        CMTime pts = CMTimeMake(self.frameIndex, 24);
        VTEncodeInfoFlags flags;
        OSStatus statusCode = VTCompressionSessionEncodeFrame(_compressionSession, imageBuffer, pts, kCMTimeInvalid, NULL, NULL, &flags);
        if (statusCode != noErr) {
            
            NSLog(@"VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            [self stopSessionEncode];
        }
        NSLog(@"开始编码一帧数据");
    });
}

/*!
    停止编码
 */
- (void) stopSessionEncode {
    
    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(_compressionSession);
    
    CFRelease(_compressionSession);
    _compressionSession = NULL;
}
#pragma 编码回调，每当系统编码完一帧之后，会异步掉用该方法，此为c语言方法
void didCompressionCallback(void * CM_NULLABLE outputCallbackRefCon,
                            void * CM_NULLABLE sourceFrameRefCon,
                            OSStatus status,
                            VTEncodeInfoFlags infoFlags,
                            CM_NULLABLE CMSampleBufferRef sampleBuffer){
    if (status != noErr) {
        NSLog(@"didCompressH264 error: with status %d, infoFlags %d", (int)status, (int)infoFlags);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264encoder *encoder =  (__bridge H264encoder *)outputCallbackRefCon;
    
    // 判断该帧是否是关键帧
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    BOOL isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    
    //获取sps & pps数据. sps pps只需获取一次，保存在h264文件开头即可
    if (isKeyFrame && !encoder->_spsppsFound) {
        

        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取SPS信息
        const uint8_t *spsOut;
        size_t spsSize, spsCount;
        OSStatus err0 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsOut, &spsSize, &spsCount, NULL);
        
        // 获取PPS信息
        const uint8_t *ppsOut;
        size_t ppsSize, ppsCount;
        OSStatus err1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsOut, &ppsSize, &ppsCount, NULL);
        
        
        // 将SPS/PPS转成NSData, 并且写入文件
        NSData *spsData = [NSData dataWithBytes:spsOut length:spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsOut length:ppsSize];
        if (err0==noErr && err1==noErr) {

            encoder->_spsppsFound = 1;
            // 写入sps pps
            [encoder writeH264Data:spsData addStartCode:YES];
            [encoder writeH264Data:ppsData addStartCode:YES];

            NSLog(@"got sps/pps data. Length: sps=%zu, pps=%zu", spsSize, ppsSize);
        }
    }
   // 获取编码后的数据, 写入文件
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t lengthAtOffset, totalLength;
    char *dataPointer;
    OSStatus error = CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &dataPointer);
    if (error == noErr) {
        size_t bufferOffset = 0;
       static const int headerLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        NSLog(@"--------");
        while (bufferOffset < totalLength - headerLength) {
            uint32_t naluLength = 0;
            memcpy(&naluLength, dataPointer + bufferOffset, headerLength);
            // 大端模式/小端模式-->系统模式
            // H264编码的数据是大端模式(字节序)
            naluLength = CFSwapInt32BigToHost(naluLength);
            NSLog(@"got nalu data, length=%d, totalLength=%zu", naluLength, totalLength);

            
            NSData *data =  [NSData dataWithBytes:dataPointer + bufferOffset + headerLength length:naluLength];

            [encoder writeH264Data:data addStartCode:YES];
            //读取下一个nalu，一次回调可能包含多个nalu
            bufferOffset += naluLength + headerLength;
        }
        NSLog(@"=======");
        
    }
 
}
- (void)writeH264Data: (NSData *)data addStartCode:(BOOL)b {
    // 拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    if (self.fileHandle != NULL) {
        if (b) {
            [self.fileHandle writeData:byteHeader];
        }
        
        [self.fileHandle writeData:data];
    } else {
        
        NSLog(@"_h264File null error");
    }

}

@end
