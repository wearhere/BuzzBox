//
//  BBProjectionViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBProjectionViewController.h"
#import "BBReceiver.h"

#import <QuartzCore/QuartzCore.h>

static const CGSize kClipSize = (CGSize){280.0f, 280.0f};
static const CGFloat kClipCornerRadius = 8.0f;
static const CGFloat kClipFrameBorderWidth = 5.0f;
static const NSTimeInterval kClipToggleDuration = 0.1;

typedef NS_ENUM(NSUInteger, ClipState) {
    ClipStateFrameShown,
    ClipStateClipShown
};

@interface BBProjectionViewController () <UIGestureRecognizerDelegate>
@property (nonatomic) BOOL interfaceShown;
@property (nonatomic) ClipState clipState;
@property (nonatomic) NSUInteger currentClipIndex;
@property (nonatomic, strong) AVPlayerItem *currentClipItem;
@property (nonatomic, strong) NSArray *currentIllustrationImages;
@end

@implementation BBProjectionViewController {
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
    UIImageView *_videoBlurImageView;

    NSArray *_clips;
    CALayer *_clipFrameLayer;
    AVPlayerLayer *_clipPlayerLayer;
    UIImageView *_illustrationImageView;

    UITapGestureRecognizer *_toggleInterfaceGestureRecognizer;
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_nextClipGestureRecognizer;
    BBReceiver *_receiver;
}

- (id)initWithAVCaptureSession:(AVCaptureSession *)session receiver:(BBReceiver *)receiver {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        NSParameterAssert(session);
#if !TARGET_IPHONE_SIMULATOR
        NSParameterAssert(receiver);
#endif
        _session = session;
        _receiver = receiver;

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

    _videoBlurImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"blur.png"]];
    _videoBlurImageView.alpha = 0.0f;
    [view.layer addSublayer:_videoBlurImageView.layer];

    _clipFrameLayer = [CALayer layer];
    _clipFrameLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _clipFrameLayer.opaque = NO;
    _clipFrameLayer.borderColor = [[UIColor colorWithRed:40.0f/255.0f green:135.0f/255.0f blue:170.0f/255.0f alpha:1.0f] CGColor];
    _clipFrameLayer.borderWidth = kClipFrameBorderWidth;
    _clipFrameLayer.cornerRadius = kClipCornerRadius + kClipFrameBorderWidth;
    _clipFrameLayer.shadowOpacity = 0.5f;
    _clipFrameLayer.shadowOffset = CGSizeMake(0.0f, 3.0f);
    [view.layer addSublayer:_clipFrameLayer];

    _clipPlayerLayer = [AVPlayerLayer layer];
    // the clear background color allows us to show the layer before the video has loaded
    _clipPlayerLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _clipPlayerLayer.cornerRadius = kClipCornerRadius;
    _clipPlayerLayer.masksToBounds = YES;
    _clipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    AVPlayer *avPlayer = [AVPlayer playerWithPlayerItem:self.currentClipItem];
    avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    _clipPlayerLayer.player = avPlayer;
    [view.layer addSublayer:_clipPlayerLayer];

    _illustrationImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _illustrationImageView.contentMode = UIViewContentModeScaleAspectFill;
    [view addSubview:_illustrationImageView];

    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self updateViews];

    _toggleInterfaceGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleInterface)];
    _toggleInterfaceGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleInterfaceGestureRecognizer];

    _toggleClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleClip)];
    _toggleClipGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleClipGestureRecognizer];

    _nextClipGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextClip)];
    _nextClipGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:_nextClipGestureRecognizer];

    [self registerMessageHandlers];
}

- (void)registerMessageHandlers {
    BBProjectionViewController *__weak weakSelf = self;

    [_receiver registerMessageReceived:@"toggleInterface" handler:^{
        [weakSelf toggleInterface];
    }];
    [_receiver registerMessageReceived:@"toggleClip" handler:^{
        [weakSelf toggleClip];
    }];
    [_receiver registerMessageReceived:@"nextClip" handler:^{
        [weakSelf nextClip];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateVideoPreviewOrientation:self.interfaceOrientation];
    if (_clipState == ClipStateClipShown) [_clipPlayerLayer.player play];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    _videoPreviewLayer.frame = self.view.bounds;
    _videoBlurImageView.frame = self.view.bounds;

    _clipPlayerLayer.bounds = (CGRect){CGPointZero, kClipSize};
    _clipPlayerLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));

    _clipFrameLayer.bounds = CGRectInset(_clipPlayerLayer.bounds, -_clipFrameLayer.borderWidth, -_clipFrameLayer.borderWidth);
    _clipFrameLayer.position = _clipPlayerLayer.position;

    _illustrationImageView.frame = self.view.bounds;
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL touchIsInLeftHalf = ([touch locationInView:self.view].x < CGRectGetMidX(self.view.bounds));
    if (gestureRecognizer == _toggleInterfaceGestureRecognizer) {
        return touchIsInLeftHalf;
    } else if (gestureRecognizer == _toggleClipGestureRecognizer) {
        return !touchIsInLeftHalf;
    } else {
        return YES;
    }
}

- (void)setInterfaceShown:(BOOL)interfaceShown {
    if (interfaceShown != _interfaceShown) {
        _interfaceShown = interfaceShown;
        [self updateViews];
    }
}

- (void)toggleInterface {
    self.interfaceShown = !self.interfaceShown;
}

- (void)incrementClipState {
    ClipState newClipState;
    switch (self.clipState) {
        case ClipStateFrameShown:
            newClipState = ClipStateClipShown;
            break;
        case ClipStateClipShown:
            newClipState = ClipStateFrameShown;
            break;
    }
    self.clipState = newClipState;
}

- (void)setClipState:(ClipState)clipState {
    if (clipState != _clipState) {
        _clipState = clipState;
        [self updateViews];
    }
}

- (void)updateViews {
    [CATransaction begin];
    [CATransaction setAnimationDuration:kClipToggleDuration];
    if (self.interfaceShown &&
        (self.clipState == ClipStateClipShown)) {
        _clipPlayerLayer.hidden = NO;
        [_clipPlayerLayer.player play];
    } else {
        [_clipPlayerLayer.player pause];
        _clipPlayerLayer.hidden = YES;
    }

    if (self.interfaceShown &&
        (self.clipState == ClipStateFrameShown || self.clipState == ClipStateClipShown)) {
        _clipFrameLayer.hidden = NO;
    } else {
        _clipFrameLayer.hidden = YES;
    }
    [CATransaction commit];

    if (self.interfaceShown) {
        [UIView animateWithDuration:kClipToggleDuration animations:^{
            _videoBlurImageView.alpha = 1.0f;
        }];
    }

    [UIView animateWithDuration:kClipToggleDuration animations:^{
        if (!self.interfaceShown && [self.currentIllustrationImages count]) {
            _illustrationImageView.alpha = 1.0f;
            // retrieve the animation images if necessary
            _illustrationImageView.animationImages = self.currentIllustrationImages;
            _illustrationImageView.animationDuration = 3.0;
            [_illustrationImageView startAnimating];
        } else {
            [_illustrationImageView stopAnimating];
            _illustrationImageView.alpha = 0.0f;
        }
    }];
}

- (void)setCurrentClipIndex:(NSUInteger)currentClipIndex {
    if (currentClipIndex != _currentClipIndex) {
        _currentClipIndex = currentClipIndex;

        // refresh media
        self.currentClipItem = nil;
        [_clipPlayerLayer.player replaceCurrentItemWithPlayerItem:self.currentClipItem];
        self.currentIllustrationImages = nil;
        _illustrationImageView.animationImages = self.currentIllustrationImages;
    }
}

- (AVPlayerItem *)currentClipItem {
    if (!_currentClipItem) {
        // the clip names include their extensions
        NSString *clipPath = [[NSBundle mainBundle] pathForResource:_clips[self.currentClipIndex] ofType:nil];
        NSURL *clipURL = [NSURL fileURLWithPath:clipPath];
        _currentClipItem = [AVPlayerItem playerItemWithURL:clipURL];
    }
    return _currentClipItem;
}

- (NSArray *)currentIllustrationImages {
    if (!_currentIllustrationImages) {
        NSString *currentClipName = [_clips[self.currentClipIndex] stringByDeletingPathExtension];

        NSMutableArray *images = [NSMutableArray array];
        for (NSString *imagePath in [[NSBundle mainBundle] pathsForResourcesOfType:nil inDirectory:currentClipName]) {
            UIImage *image = [[UIImage alloc] initWithContentsOfFile:imagePath];
            [images addObject:image];
        }
        _currentIllustrationImages = [images copy];
    }
    return _currentIllustrationImages;
}

- (void)nextClip {
    // loop over clip array
    self.currentClipIndex = ((self.currentClipIndex + 1) % [_clips count]);
}

- (void)toggleClip {
    [self incrementClipState];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    // loop the current item
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

@end
