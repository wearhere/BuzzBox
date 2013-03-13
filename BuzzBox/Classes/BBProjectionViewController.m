//
//  BBProjectionViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBProjectionViewController.h"
#import "BBProjectionIntroView.h"
#import "BBTitleLabel.h"
#import "BBReceiver.h"
#import "BBClipTableView.h"
#import "BBWizardViewController.h"

#import <QuartzCore/QuartzCore.h>


static const NSTimeInterval kClipToggleDuration = 0.1;

static const CGFloat kInstructionLabelMargin = 10.0f;

typedef NS_ENUM(NSUInteger, ClipState) {
    ClipStateClipShown,
    ClipStateFrameShown
};

@interface BBProjectionViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) BBClipView *currentClip;
@property (nonatomic, strong) NSArray *currentIllustrationImages;
@end

@implementation BBProjectionViewController {
    BBRodPosition _rodPosition;

    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
    UIImageView *_videoBlurImageView;

    BBProjectionIntroView *_introView;
    BBTitleLabel *_instructionLabel;
    NSArray *_instructions;
    NSInteger _instructionIndex;

    UITapGestureRecognizer *_toggleInterfaceGestureRecognizer;
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_previousRowGestureRecognizer, *_nextRowGestureRecognizer;
    BBReceiver *_receiver;

    UIImageView *_illustrationImageView;
    BBClipTableView *_clipTableView;
}

- (id)initWithAVCaptureSession:(AVCaptureSession *)session receiver:(BBReceiver *)receiver {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        NSParameterAssert(session);
#if !DEBUGGING_PROJECTION_VIEW
        NSParameterAssert(receiver);
#endif
        _session = session;
        _receiver = receiver;

        NSString *instructionsPath = [[NSBundle mainBundle] pathForResource:@"Instructions" ofType:@"plist"];
        _instructions = [NSArray arrayWithContentsOfFile:instructionsPath];
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

    _videoBlurImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tint-01.png"]];
    _videoBlurImageView.contentMode = UIViewContentModeScaleAspectFill;
    [view.layer addSublayer:_videoBlurImageView.layer];
    
    _introView = [[BBProjectionIntroView alloc] initWithFrame:CGRectZero];
    [view.layer addSublayer:_introView.layer];
    
    _illustrationImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _illustrationImageView.contentMode = UIViewContentModeScaleAspectFill;
    [view.layer addSublayer:_illustrationImageView.layer];

    _clipTableView = [[BBClipTableView alloc] initWithFrame:CGRectZero];
    _clipTableView.backgroundColor = [UIColor clearColor];
    _clipTableView.opaque = NO;
    _clipTableView.layer.opacity = 0.0f;
    [view.layer addSublayer:_clipTableView.layer];

    _instructionLabel = [[BBTitleLabel alloc] initWithFrame:CGRectZero];
    _instructionLabel.backgroundColor = [UIColor clearColor];
    _instructionLabel.opaque = NO;
    _instructionLabel.font = [UIFont fontWithName:@"ApexNew-Medium" size:20.0f];
    _instructionLabel.textAlignment = NSTextAlignmentCenter;
    _instructionLabel.textColor = [UIColor whiteColor];
    _instructionLabel.numberOfLines = 2;
    _instructionLabel.alpha = 0.0f;
    _instructionIndex = -1;
    _instructionLabel.text = [self nextInstruction];
    [view.layer addSublayer:_instructionLabel.layer];

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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_introView countDownWithCompletion:^{
        [UIView animateWithDuration:.3 animations:^{
            _introView.alpha = 0.0f;
            _videoBlurImageView.alpha = 0.0f;
            _instructionLabel.alpha = 1.0f;
        }];
    }];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    _videoPreviewLayer.frame = self.view.bounds;
    _videoBlurImageView.frame = self.view.bounds;
    _introView.frame = self.view.bounds;
    CGSize sizeThatFitsInstructions = [_instructionLabel sizeThatFits:CGRectInset(self.view.bounds, kInstructionLabelMargin, kInstructionLabelMargin).size];
    _instructionLabel.frame = (CGRect){ CGPointMake(CGRectGetMinX(self.view.bounds) + kInstructionLabelMargin,
                                                    CGRectGetMinY(self.view.bounds) + kInstructionLabelMargin),
                                        sizeThatFitsInstructions};

    _illustrationImageView.frame = self.view.bounds;

    _clipTableView.frame = self.view.bounds;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateVideoPreviewOrientation:toInterfaceOrientation];
}

- (NSString *)nextInstruction {
    return _instructions[++_instructionIndex];
}

- (CAAnimation *)nextInstructionTransition {
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    return transition;
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
        if (_instructionIndex == 0) {
            _instructionLabel.text = [self nextInstruction];
            [_instructionLabel.layer addAnimation:[self nextInstructionTransition] forKey:nil];
        }
        _clipTableView.layer.opacity = ((_instructionIndex < ([_instructions count] - 1)) ? 0.5f : 1.0f);
    } else {
        _clipTableView.layer.opacity = 0.0f;
    }

    if (interfaceShown && (_rodPosition.yPos == BBRodPositionYMiddle)) {
        BBClipView *newClip;
        NSInteger currentInstructionIndex = _instructionIndex;  // this may advance below
        switch (_rodPosition.xPos) {
            case BBRodPositionXLeft:
                newClip = _clipTableView.currentRow.leftClip;
                break;
            case BBRodPositionXCenter:
                if (_instructionIndex == 3) {
                    _instructionLabel.text = [self nextInstruction];
                    [_instructionLabel.layer addAnimation:[self nextInstructionTransition] forKey:nil];
                }
                newClip = _clipTableView.currentRow.centerClip;
                break;
            case BBRodPositionXRight:
                if (_instructionIndex == 1 || _instructionIndex == 2) {
                    _instructionLabel.text = [self nextInstruction];
                    [_instructionLabel.layer addAnimation:[self nextInstructionTransition] forKey:nil];

                    // confirm pause
                    double delayInSeconds = 2.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        [self updateForRodPosition];
                    });
                }
                newClip = _clipTableView.currentRow.rightClip;
                break;
            case BBRodPositionXNone:
                break;
        }
        // the user hasn't learned to pause before the third instruction
        if (currentInstructionIndex > 1) {
            self.currentClip = newClip;
        }
    } else {
        self.currentClip = nil;
    }
    [CATransaction commit];

    if (!interfaceShown && _instructionIndex == 4) {
        [UIView animateWithDuration:0.3 animations:^{
            _instructionLabel.alpha = 0.0f;
        }];
    }

    [UIView animateWithDuration:kClipToggleDuration animations:^{
        _videoBlurImageView.alpha = ((interfaceShown || _instructionIndex == 0) ? 1.0f : 0.0f);
    }];

    [UIView animateWithDuration:kClipToggleDuration animations:^{
        if (!interfaceShown && [self.currentIllustrationImages count]) {
            _illustrationImageView.alpha = 1.0f;
            // retrieve the animation images if necessary
            _illustrationImageView.animationImages = self.currentIllustrationImages;
            // 3 seconds for 4 images
            static const CGFloat kAnimationFrameRate = 3.0 / 4.0;
            _illustrationImageView.animationDuration = kAnimationFrameRate * [_illustrationImageView.animationImages count];
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

        // note that the illustration images are not cleared when the current clip is cleared
        // because the images corresponding to the last clip display while the interface is hidden
        if (_currentClip) {
            self.currentIllustrationImages = nil;
            _illustrationImageView.animationImages = self.currentIllustrationImages;
        }
    }
}

- (NSArray *)currentIllustrationImages {
    if (!_currentIllustrationImages && _currentClip) {
        NSMutableArray *images = [NSMutableArray array];
        for (NSString *imagePath in [[NSBundle mainBundle] pathsForResourcesOfType:nil inDirectory:_currentClip.name]) {
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
