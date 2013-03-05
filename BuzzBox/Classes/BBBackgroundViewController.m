//
//  BBBackgroundViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBBackgroundViewController.h"
#import <QuartzCore/QuartzCore.h>

static const CGSize kClipSize = (CGSize){250.0f, 250.0f};
static const NSTimeInterval kClipToggleDuration = 0.1;

@implementation BBBackgroundViewController {
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;

    BOOL _clipShown;
    NSArray *_clips;
    NSUInteger _currentClipIndex;
    AVPlayerLayer *_clipPlayerLayer;
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UITapGestureRecognizer *_nextClipGestureRecognizer;
}

- (id)initWithAVCaptureSession:(AVCaptureSession *)session {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        NSParameterAssert(session);
        _session = session;

        NSString *clipsPath = [[NSBundle mainBundle] pathForResource:@"Clips" ofType:@"plist"];
        _clips = [NSArray arrayWithContentsOfFile:clipsPath];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
#if TARGET_IPHONE_SIMULATOR
    // When we're running in the simulator, the camera won't work,
    // and so the video preview layer will be transparent
    // we set the background to white to give greater contrast to the clip
    view.backgroundColor = [UIColor whiteColor];
#else
    view.backgroundColor = [UIColor blackColor];
#endif
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [view.layer addSublayer:_videoPreviewLayer];

    _clipPlayerLayer = [AVPlayerLayer layer];
    _clipPlayerLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _clipPlayerLayer.cornerRadius = 8.0f;
    _clipPlayerLayer.masksToBounds = YES;
    _clipPlayerLayer.shadowOpacity = 0.5f;
    _clipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    AVPlayer *avPlayer = [AVPlayer playerWithPlayerItem:[self playerItemForNextClip]];
    avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    _clipPlayerLayer.player = avPlayer;
    _clipPlayerLayer.hidden = !_clipShown;
    [view.layer addSublayer:_clipPlayerLayer];

    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _toggleClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleClip)];
    [self.view addGestureRecognizer:_toggleClipGestureRecognizer];

    _nextClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nextClip)];
    _nextClipGestureRecognizer.numberOfTapsRequired = 2;
    // wait for the user to double tap
    [_toggleClipGestureRecognizer requireGestureRecognizerToFail:_nextClipGestureRecognizer];
    [self.view addGestureRecognizer:_nextClipGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateVideoPreviewOrientation:self.interfaceOrientation];
    if (_clipShown) [_clipPlayerLayer.player play];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    _videoPreviewLayer.frame = self.view.bounds;

    _clipPlayerLayer.bounds = (CGRect){CGPointZero, kClipSize};
    _clipPlayerLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateVideoPreviewOrientation:toInterfaceOrientation];
}

#pragma mark - Background Recording

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

#pragma mark - Clips

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    // loop the current item
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

- (AVPlayerItem *)playerItemForNextClip {
    // the clip names include their extensions
    NSString *clipPath = [[NSBundle mainBundle] pathForResource:_clips[_currentClipIndex] ofType:nil];
    // loop over clip array
    _currentClipIndex = ((_currentClipIndex + 1) % [_clips count]);
    NSURL *clipURL = [NSURL fileURLWithPath:clipPath];
    return [AVPlayerItem playerItemWithURL:clipURL];
}

- (void)showClip:(BOOL)show {
    if (show != _clipShown) {
        _clipShown = show;
        [CATransaction begin];
        [CATransaction setAnimationDuration:kClipToggleDuration];
        if (show) {
            _clipPlayerLayer.hidden = NO;
            [_clipPlayerLayer.player play];
        } else {
            [_clipPlayerLayer.player pause];
            _clipPlayerLayer.hidden = YES;
        }
        [CATransaction commit];
    }
}

- (void)nextClip {
    [_clipPlayerLayer.player replaceCurrentItemWithPlayerItem:[self playerItemForNextClip]];
    // dispatch_async to make sure that the clip has been swapped
    // by the time that the clip is shown
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showClip:YES];
    });
}

- (void)toggleClip {
    [self showClip:!_clipShown];
}

@end
