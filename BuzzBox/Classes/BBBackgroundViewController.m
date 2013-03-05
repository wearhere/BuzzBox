//
//  BBBackgroundViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBBackgroundViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation BBBackgroundViewController {
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
}

- (id)initWithAVCaptureSession:(AVCaptureSession *)session {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        NSParameterAssert(session);
        _session = session;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [UIColor whiteColor];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _videoPreviewLayer.frame = view.layer.bounds;
    [view.layer addSublayer:_videoPreviewLayer];

    self.view = view;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateVideoPreviewOrientation:self.interfaceOrientation];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _videoPreviewLayer.frame = self.view.bounds;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateVideoPreviewOrientation:toInterfaceOrientation];
}

- (void)updateVideoPreviewOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    if (!_videoPreviewLayer.connection.supportsVideoOrientation) return;
    
    AVCaptureVideoOrientation videoOrientation = _videoPreviewLayer.connection.videoOrientation;
	if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
		videoOrientation = AVCaptureVideoOrientationPortrait;
    } else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }

    _videoPreviewLayer.connection.videoOrientation = videoOrientation;
}

@end
