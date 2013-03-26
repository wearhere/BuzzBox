//
//  BBWizardViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBWizardViewController.h"
#import "BBSender.h"

#import <QuartzCore/QuartzCore.h>


@interface BBFenceView : UIView
@end

@implementation BBFenceView

+ (Class)layerClass {
    return [CAShapeLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        CAShapeLayer *layer = (CAShapeLayer *)self.layer;
        layer.fillColor = [UIColor clearColor].CGColor;
        layer.strokeColor = [UIColor blackColor].CGColor;
        // because the fence is 1px tall,
        // we only want to stroke "the top"--stroking "the bottom" too
        // will result in the strokes overlapping
        layer.strokeEnd = 0.5;
        layer.lineDashPattern = @[ @(20), @(20) ];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    ((CAShapeLayer *)self.layer).path = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
}

@end


static const CGSize kRodSize = {80.0f, 80.0f};

@interface BBWizardViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, readonly) CGRect leftArea, centerArea, rightArea;
@property (nonatomic, readonly) CGRect topArea, middleArea, bottomArea;

@property (weak, nonatomic) IBOutlet UIView *deadMansSwitchView;

@property (nonatomic) BOOL deadMansSwitchPressed;
@property (nonatomic) BOOL rodHeld;

@end

@implementation BBWizardViewController {
    BBSender *_sender;

    BBRodPosition _rodPosition;
    BBRodPositionY _previousRowPosition;
    BOOL _transitionedDuringPreviousUpdate;
    UIView *_rodView;
    BOOL _haltTrackingRodViewX;
    UIPanGestureRecognizer *_gridDragGestureRecognizer;
    UILongPressGestureRecognizer *_deadMansSwitchPressRecognizer;
}

- (id)initWithSender:(BBSender *)sender {
    self = [super init];
    if (self) {
#if !DEBUGGING_WIZARD_VIEW
        NSParameterAssert(sender);
#endif
        _sender = sender;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _rodView = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, kRodSize}];
    _rodView.center = CGPointMake(160, 60);
    _rodView.backgroundColor = [UIColor blueColor];
    _rodView.layer.cornerRadius = CGRectGetWidth(_rodView.frame) / 2.0f;
    [self.view addSubview:_rodView];

    _gridDragGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(topDownRodDragged:)];
    [_rodView addGestureRecognizer:_gridDragGestureRecognizer];

    _deadMansSwitchPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(deadMansSwitchPressed:)];
    _deadMansSwitchPressRecognizer.minimumPressDuration = 0.25;
    [self.deadMansSwitchView addGestureRecognizer:_deadMansSwitchPressRecognizer];    
}

- (CGRect)leftArea {
    return (CGRect){20, 20, 80, 280};
}

- (CGRect)centerArea {
    return (CGRect){120, 20, 80, 280};
}

- (CGRect)rightArea {
    return (CGRect){220, 20, 80, 280};}

- (CGRect)topArea {
    return (CGRect){20, 20, 280, 80};}

- (CGRect)middleArea {
    return (CGRect){20, 120, 280, 80};}

- (CGRect)bottomArea {
    return (CGRect){20, 220, 280, 80};}

- (void)topDownRodDragged:(UIPanGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
#if ONE_HANDED_WIZARD
            _deadMansSwitchPressed = YES;
#endif
        case UIGestureRecognizerStateChanged:
            self.rodHeld = YES;

            // update position of rod, with caveat that it cannot not travel right onto the up-down view
            CGPoint rodTranslation = [recognizer translationInView:_rodView.superview];
            [recognizer setTranslation:CGPointZero inView:_rodView.superview];

            CGRect newRodFrame = CGRectOffset(_rodView.frame, rodTranslation.x, rodTranslation.y);
            CGFloat deadMansSwitchLeftEdge = CGRectGetMinX(self.deadMansSwitchView.frame);
            if (CGRectGetMaxX(newRodFrame) > deadMansSwitchLeftEdge) {
                newRodFrame.origin.x = deadMansSwitchLeftEdge - CGRectGetWidth(newRodFrame);
                _haltTrackingRodViewX = YES;
            } else if (_haltTrackingRodViewX) {
                // wait to update the rod's x position
                // until the user's finger aligns with the rod again
                CGPoint recognizerLocation = [recognizer locationInView:self.view];
                if (recognizerLocation.x > _rodView.center.x) {
                    newRodFrame.origin.x = _rodView.frame.origin.x;
                } else {
                    _haltTrackingRodViewX = NO;
                }
            }

            _rodView.frame = newRodFrame;

            [self updateRodPosition];
            break;
        default:
#if ONE_HANDED_WIZARD
            _deadMansSwitchPressed = NO;
#endif
            self.rodHeld = NO;
            [self updateRodPosition];
            break;
    }
}

- (void)deadMansSwitchPressed:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            self.deadMansSwitchPressed = YES;
            break;
        default:
            self.deadMansSwitchPressed = NO;
            break;
    }
}

- (void)setDeadMansSwitchPressed:(BOOL)deadMansSwitchPressed {
    if (deadMansSwitchPressed != _deadMansSwitchPressed) {
        _deadMansSwitchPressed = deadMansSwitchPressed;
        [self updateRodPosition];
    }
}

- (void)updateRodPosition {
    // update position
    BBRodPosition newRodPos = {BBRodPositionXNone, BBRodPositionYNone, BBRodPositionZBack};
    if (self.deadMansSwitchPressed) {
        newRodPos.zPos = BBRodPositionZFront;
    }

    // x, y positions can only assume non-default values if the rod is held
    if (self.rodHeld) {
        CGPoint rodCenter = _rodView.center;

        if (CGRectContainsPoint(self.leftArea, rodCenter)) {
            newRodPos.xPos = BBRodPositionXLeft;
        } else if (CGRectContainsPoint(self.centerArea, rodCenter)) {
            newRodPos.xPos = BBRodPositionXCenter;
        } else if (CGRectContainsPoint(self.rightArea, rodCenter)) {
            newRodPos.xPos = BBRodPositionXRight;
        }

        if (CGRectContainsPoint(self.topArea, rodCenter)) {
            newRodPos.yPos = BBRodPositionYUp;
        } else if (CGRectContainsPoint(self.middleArea, rodCenter)) {
            newRodPos.yPos = BBRodPositionYMiddle;
        } else if (CGRectContainsPoint(self.bottomArea, rodCenter)) {
            newRodPos.yPos = BBRodPositionYDown;
        }
    }

    // generate notifications
    if (newRodPos.zPos != _rodPosition.zPos) {
        [_sender sendMessage:@"zPosChanged" args:@[ @(newRodPos.zPos) ]];
    }
    if (newRodPos.xPos != _rodPosition.xPos) {
        [_sender sendMessage:@"xPosChanged" args:@[ @(newRodPos.xPos) ]];
    }
    if (newRodPos.yPos != _rodPosition.yPos || _transitionedDuringPreviousUpdate) {
        _transitionedDuringPreviousUpdate = NO;
        if (newRodPos.yPos == BBRodPositionYNone) {
            [_sender sendMessage:@"yPosChanged" args:@[ @(BBRodPositionYNone) ]];
        } else {
            if (_previousRowPosition != BBRodPositionYNone) {
                if (newRodPos.yPos < _previousRowPosition) {
                    [_sender sendMessage:@"yPosChanged" args:@[ @(BBRodPositionYUp) ]];
                    _transitionedDuringPreviousUpdate = YES;
                } else if (newRodPos.yPos == _previousRowPosition) {
                    [_sender sendMessage:@"yPosChanged" args:@[ @(BBRodPositionYMiddle) ]];
                } else {
                    [_sender sendMessage:@"yPosChanged" args:@[ @(BBRodPositionYDown) ]];
                    _transitionedDuringPreviousUpdate = YES;
                }
            } else {
                [_sender sendMessage:@"yPosChanged" args:@[ @(BBRodPositionYMiddle) ]];
            }
            _previousRowPosition = newRodPos.yPos;
        }
    }

    _rodPosition = newRodPos;
}

@end
