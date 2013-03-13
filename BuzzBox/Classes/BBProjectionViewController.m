//
//  BBProjectionViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBProjectionViewController.h"
#import "BBReceiver.h"
#import "BBClipTableView.h"
#import "BBWizardViewController.h"

#import <QuartzCore/QuartzCore.h>


static const NSTimeInterval kClipToggleDuration = 0.1;

static const NSTimeInterval kRowSwapRepeatDelay = 0.75;

typedef NS_ENUM(NSUInteger, ClipState) {
    ClipStateClipShown,
    ClipStateFrameShown
};

@interface BBProjectionViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) BBClipView *currentClip;
@property (nonatomic) NSUInteger currentClipIndex;
@property (nonatomic, strong) AVPlayerItem *currentClipItem;
@property (nonatomic, strong) NSArray *currentIllustrationImages;
@end

@implementation BBProjectionViewController {
    BBRodPosition _rodPosition;

    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
    UIImageView *_videoBlurImageView;

    NSArray *_clips;
    CALayer *_clipFrameLayer;
    AVPlayerLayer *_clipPlayerLayer;
    UIImageView *_illustrationImageView;

    UITapGestureRecognizer *_toggleInterfaceGestureRecognizer;
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_previousRowGestureRecognizer, *_nextRowGestureRecognizer;
    BBReceiver *_receiver;

    BBClipTableView *_clipTableView;
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

    _illustrationImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _illustrationImageView.contentMode = UIViewContentModeScaleAspectFill;
    [view addSubview:_illustrationImageView];

    _clipTableView = [[BBClipTableView alloc] initWithFrame:CGRectZero];
    _clipTableView.backgroundColor = [UIColor clearColor];
    _clipTableView.opaque = NO;
    _clipTableView.layer.opacity = 0.0f;
    [view addSubview:_clipTableView];

    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self updateForRodPosition];

    _toggleInterfaceGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleInterface)];
    _toggleInterfaceGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleInterfaceGestureRecognizer];

    _toggleClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleClip)];
    _toggleClipGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleClipGestureRecognizer];

    _previousRowGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(previousRow)];
    _previousRowGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:_previousRowGestureRecognizer];

    _nextRowGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextRow)];
    _nextRowGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:_nextRowGestureRecognizer];

    [self registerMessageHandlers];
}

- (void)registerMessageHandlers {
    BBProjectionViewController *__weak weakSelf = self;

    [_receiver registerMessageReceived:@"zPosChanged" handler:^(NSArray *args) {
        BBProjectionViewController *strongSelf = weakSelf;
        [args[0] getValue:&(strongSelf->_rodPosition.zPos)];
        [strongSelf updateForRodPosition];
    }];
    [_receiver registerMessageReceived:@"xPosChanged" handler:^(NSArray *args) {
        BBProjectionViewController *strongSelf = weakSelf;
        [args[0] getValue:&(strongSelf->_rodPosition.xPos)];
        [strongSelf updateForRodPosition];
    }];
    [_receiver registerMessageReceived:@"yPosChanged" handler:^(NSArray *args) {
        BBProjectionViewController *strongSelf = weakSelf;
        [args[0] getValue:&(strongSelf->_rodPosition.yPos)];
        [strongSelf updateForRodPosition];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateVideoPreviewOrientation:self.interfaceOrientation];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    _videoPreviewLayer.frame = self.view.bounds;
    _videoBlurImageView.frame = self.view.bounds;

    _illustrationImageView.frame = self.view.bounds;

    _clipTableView.frame = self.view.bounds;
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

- (void)toggleInterface {
    if (_rodPosition.zPos == BBRodPositionZBack) {
        _rodPosition.zPos = BBRodPositionZFront;
    } else {
        _rodPosition.zPos = BBRodPositionZBack;
    }
    [self updateForRodPosition];
}

- (void)updateForRodPosition {
    [CATransaction begin];
    [CATransaction setAnimationDuration:kClipToggleDuration];
    BOOL interfaceShown = (_rodPosition.zPos == BBRodPositionZFront);
    if (interfaceShown) {
        _clipTableView.layer.opacity = 1.0f;
    } else {
        _clipTableView.layer.opacity = 0.0f;
    }

    if (interfaceShown && (_rodPosition.yPos == BBRodPositionYMiddle)) {
        BBClipView *newClip;
        switch (_rodPosition.xPos) {
            case BBRodPositionXLeft:
                newClip = _clipTableView.currentRow.leftClip;
                break;
            case BBRodPositionXCenter:
                newClip = _clipTableView.currentRow.centerClip;
                break;
            case BBRodPositionXRight:
                newClip = _clipTableView.currentRow.rightClip;
                break;
            case BBRodPositionXNone:
                break;
        }
        self.currentClip = newClip;
    } else {
        self.currentClip = nil;
    }
    [CATransaction commit];

    [UIView animateWithDuration:kClipToggleDuration animations:^{
        _videoBlurImageView.alpha = (interfaceShown ? 1.0f : 0.0f);
    }];

    [UIView animateWithDuration:kClipToggleDuration animations:^{
        if (!interfaceShown && [self.currentIllustrationImages count]) {
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

    if (_rodPosition.yPos == BBRodPositionYUp) {
        [self previousRow];
    } else if (_rodPosition.yPos == BBRodPositionYDown) {
        [self nextRow];
    }
}

- (void)setCurrentClip:(BBClipView *)currentClip {
    if (currentClip != _currentClip) {
        [_currentClip setSelected:NO];
        _currentClip = currentClip;
        [_currentClip setSelected:YES];
    }
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
        NSString *clipPath = [[NSBundle mainBundle] pathForResource:@"FreePlay_2.mov" ofType:nil inDirectory:@"Free Play"];
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

- (void)previousRow {
    [_clipTableView previousRow];
}

- (void)nextRow {
    [_clipTableView nextRow];
}

- (void)toggleClip {
    _rodPosition.yPos = BBRodPositionYMiddle;
    if (_rodPosition.xPos == BBRodPositionXNone) {
        _rodPosition.xPos = BBRodPositionXCenter;
    } else {
        _rodPosition.xPos = BBRodPositionXNone;
    }
    [self updateForRodPosition];
}

@end
