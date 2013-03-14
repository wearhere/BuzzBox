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
#import "GPUImage.h"


NSString *const BBInstructionIndexChanged = @"BBInstructionIndexChanged";

static const NSTimeInterval kClipToggleDuration = 0.3;

static const CGFloat kInstructionLabelMargin = 10.0f;

typedef NS_ENUM(NSUInteger, ClipState) {
    ClipStateClipShown,
    ClipStateFrameShown
};

@interface BBProjectionViewController () <UIGestureRecognizerDelegate>
@property (nonatomic) BOOL backgroundBlurred;
@property (nonatomic, weak) BBClipView *currentClip;
@property (nonatomic, strong) NSArray *currentIllustrationImages;
@end

@implementation BBProjectionViewController {
    BBRodPosition _rodPosition;

    AVCaptureSession *_session;
    GPUImageView *_filteredVideoView;
    GPUImageVideoCamera *_videoCamera;
    GPUImageFastBlurFilter *_filter;

    BBProjectionIntroView *_introView;
    BBTitleLabel *_instructionLabel;
    NSArray *_instructions;
    NSInteger _instructionIndex;

    UITapGestureRecognizer *_toggleInterfaceGestureRecognizer;
    UITapGestureRecognizer *_beginTutorialGestureRecognizer;
    UISwipeGestureRecognizer *_previousRowGestureRecognizer, *_nextRowGestureRecognizer;
    BBReceiver *_receiver;

    UIImageView *_illustrationImageView;
    BBClipTableView *_clipTableView;
}

static BBProjectionViewController *__projectionViewController = nil;
+ (NSInteger)instructionIndex {
    return __projectionViewController->_instructionIndex;
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

        __projectionViewController = self;
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

    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;

    _filter = [[GPUImageFastBlurFilter alloc] init];
    _filter.blurPasses = 5;
    _filter.blurSize = 5.0f;
    _filteredVideoView = [[GPUImageView alloc] initWithFrame:view.bounds];
    _filteredVideoView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [view.layer addSublayer:_filteredVideoView.layer];

    // start un-filtered
    [_videoCamera addTarget:_filteredVideoView];

    _introView = [[BBProjectionIntroView alloc] initWithFrame:CGRectZero];
    _introView.alpha = 0.0f;
    [view.layer addSublayer:_introView.layer];
    
    _illustrationImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _illustrationImageView.contentMode = UIViewContentModeScaleAspectFill;
    [view.layer addSublayer:_illustrationImageView.layer];

    _clipTableView = [[BBClipTableView alloc] initWithFrame:view.bounds];
    _clipTableView.backgroundColor = [UIColor clearColor];
    _clipTableView.opaque = NO;
    _clipTableView.alpha = 0.0f;
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

    [_videoCamera startCameraCapture];

    [self updateForRodPosition];

    _toggleInterfaceGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleInterface)];
    _toggleInterfaceGestureRecognizer.delegate = self;
    [_filteredVideoView addGestureRecognizer:_toggleInterfaceGestureRecognizer];

    _beginTutorialGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(beginTutorial)];
    _beginTutorialGestureRecognizer.delegate = self;
    [_filteredVideoView addGestureRecognizer:_beginTutorialGestureRecognizer];

    _previousRowGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(previousRow)];
    _previousRowGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [_filteredVideoView addGestureRecognizer:_previousRowGestureRecognizer];

    _nextRowGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextRow)];
    _nextRowGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [_filteredVideoView addGestureRecognizer:_nextRowGestureRecognizer];

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

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    _filteredVideoView.frame = self.view.bounds;
    _introView.frame = self.view.bounds;
    CGRect insetRect = CGRectInset(self.view.bounds, kInstructionLabelMargin, kInstructionLabelMargin);
    CGSize sizeThatFitsInstructions = [_instructionLabel sizeThatFits:insetRect.size];
    _instructionLabel.frame = (CGRect){ CGPointMake(CGRectGetMinX(self.view.bounds) + kInstructionLabelMargin,
                                                    CGRectGetMinY(self.view.bounds) + kInstructionLabelMargin),
                                        CGSizeMake(CGRectGetWidth(insetRect), sizeThatFitsInstructions.height)};
    [_instructionLabel setNeedsDisplay];

    _illustrationImageView.frame = self.view.bounds;

    _clipTableView.frame = self.view.bounds;
}

- (void)setBackgroundBlurred:(BOOL)backgroundBlurred {
    if (backgroundBlurred != _backgroundBlurred) {
        _backgroundBlurred = backgroundBlurred;
        if (backgroundBlurred) {
            [_videoCamera removeTarget:_filteredVideoView];
            [_videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        } else {
            [_filter removeTarget:_filteredVideoView];
            [_videoCamera removeTarget:_filter];
            [_videoCamera addTarget:_filteredVideoView];
        }
    }
}

- (NSString *)nextInstruction {
    NSString *nextInstruction = _instructions[++_instructionIndex];
    [[NSNotificationCenter defaultCenter] postNotificationName:BBInstructionIndexChanged object:nil];
    return nextInstruction;
}

- (CAAnimation *)nextInstructionTransition {
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    return transition;
}

#pragma mark - Clips

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL debuggingProjectionView = NO;
#if DEBUGGING_PROJECTION_VIEW
    debuggingProjectionView = YES;
#endif

    // when debugging, the view will be split down the middle
    // when running for real, the view will be entirely given over to starting the tutorial
    // to minimize user error
    BOOL touchIsInLeftHalf = ([touch locationInView:self.view].x < CGRectGetMidX(self.view.bounds));
    if (gestureRecognizer == _toggleInterfaceGestureRecognizer) {
        return (debuggingProjectionView ? touchIsInLeftHalf : NO);
    } else if (gestureRecognizer == _beginTutorialGestureRecognizer) {
        return (debuggingProjectionView ? !touchIsInLeftHalf : YES);
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
    BOOL interfaceShown = (_rodPosition.zPos == BBRodPositionZFront);
    [UIView animateWithDuration:kClipToggleDuration animations:^{
        if (interfaceShown) {
            if (_instructionIndex == 0) {
                _instructionLabel.text = [self nextInstruction];
                [_instructionLabel.layer addAnimation:[self nextInstructionTransition] forKey:nil];
            }
            _clipTableView.alpha = ((_instructionIndex < [_instructions count]) ? 0.5f : 1.0f);
        } else {
            _clipTableView.alpha = 0.0f;
        }
    }];

    if (interfaceShown && (_rodPosition.yPos == BBRodPositionYMiddle)) {
        BBClipView *newClip;
        NSInteger currentInstructionIndex = _instructionIndex;  // this may advance below
        switch (_rodPosition.xPos) {
            case BBRodPositionXLeft:
                newClip = _clipTableView.currentRow.leftClip;
                break;
            case BBRodPositionXCenter:
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

    if (!interfaceShown && _instructionIndex == 4) {
        [UIView animateWithDuration:0.3 animations:^{
            _instructionLabel.alpha = 0.0f;
        }];
        _instructionIndex++;
    }

    [self setBackgroundBlurred:interfaceShown];

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
        if (_instructionIndex == 3) {
            _instructionLabel.text = [self nextInstruction];
            [_instructionLabel.layer addAnimation:[self nextInstructionTransition] forKey:nil];
        }
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

- (void)beginTutorial {
    [UIView animateWithDuration:0.3 animations:^{
        [self setBackgroundBlurred:YES];
        _introView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        [_introView countDownWithCompletion:^{
            [UIView animateWithDuration:.3 animations:^{
                _introView.alpha = 0.0f;
                [self setBackgroundBlurred:NO];
                _instructionLabel.alpha = 1.0f;
            }];
        }];
    }];
}

@end
