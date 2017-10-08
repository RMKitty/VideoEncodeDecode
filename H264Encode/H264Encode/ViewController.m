//
//  ViewController.m
//  H264Encode
//
//  Created by Kitty on 2017/5/3.
//  Copyright © 2017年 RM. All rights reserved.
//

#import "ViewController.h"
#import "VideoCapture.h"

@interface ViewController ()
@property (nonatomic,strong) VideoCapture *videoCapture;
@end

@implementation ViewController

- (VideoCapture *)videoCapture {
    
    if (!_videoCapture) {
        _videoCapture = [VideoCapture new];
    }
    return _videoCapture;
}
- (IBAction)start:(id)sender {
    
    [self.videoCapture startCapturing:self.view];
}
- (IBAction)stop:(id)sender {
    
    [self.videoCapture stopCapturing];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
