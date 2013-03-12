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


typedef NS_ENUM(NSUInteger, BBRodPositionX) {
    BBRodPositionXNone,
    BBRodPositionXLeft,
    BBRodPositionXMiddle,
    BBRodPositionXRight
};

typedef NS_ENUM(NSUInteger, BBRodPositionY) {
    BBRodPositionYNone,
    BBRodPositionYUp,
    BBRodPositionYDown
};

typedef NS_ENUM(NSUInteger, BBRodPositionZ) {
    BBRodPositionZBack,
    BBRodPositionZFront
};

struct BBRodPosition {
    BBRodPositionX xPos;
    BBRodPositionY yPos;
    BBRodPositionZ zPos;
};
typedef struct BBRodPosition BBRodPosition;

static const CGSize kRodSize = {50.0f, 50.0f};


@interface BBWizardViewController () <UIGestureRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UIView *flameView;
@property (weak, nonatomic) IBOutlet BBFenceView *fenceView;
@property (weak, nonatomic) IBOutlet UIView *rodLeftView;
@property (weak, nonatomic) IBOutlet UIView *rodMiddleView;
@property (weak, nonatomic) IBOutlet UIView *rodRightView;
@property (weak, nonatomic) IBOutlet UIView *upDownView;
@property (weak, nonatomic) IBOutlet UIView *rodUpView;
@property (weak, nonatomic) IBOutlet UIView *rodDownView;

@end

@implementation BBWizardViewController {
    BBSender *_sender;

    BBRodPosition _rodPosition;
    UIView *_topDownRodView, *_frontBackRodView;
    BOOL _haltTrackingRodViewX;
    UIPanGestureRecognizer *_topDownRodDragGestureRecognizer, *_frontBackRodDragGestureRecognizer;
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

    _topDownRodView = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, kRodSize}];
    _topDownRodView.center = self.flameView.center;
    _topDownRodView.backgroundColor = [UIColor blueColor];
    _topDownRodView.layer.cornerRadius = CGRectGetWidth(_topDownRodView.frame) / 2.0f;
    [self.view addSubview:_topDownRodView];

    _topDownRodDragGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(topDownRodDragged:)];
    [_topDownRodView addGestureRecognizer:_topDownRodDragGestureRecognizer];

    _frontBackRodView = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, kRodSize}];
    _frontBackRodView.center = [self.upDownView.superview convertPoint:self.upDownView.center toView:self.upDownView];
    _frontBackRodView.backgroundColor = [UIColor blueColor];
    _frontBackRodView.layer.cornerRadius = CGRectGetWidth(_frontBackRodView.frame) / 2.0f;
    [self.upDownView addSubview:_frontBackRodView];

    _frontBackRodDragGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(frontBackRodDragged:)];
    [_frontBackRodView addGestureRecognizer:_frontBackRodDragGestureRecognizer];

    self.fenceView.backgroundColor = [UIColor clearColor];   // fence will stroke itself
}

- (void)topDownRodDragged:(UIPanGestureRecognizer *)recognizer {
    // update position of rod, with caveat that it cannot not travel right onto the up-down view
    CGPoint rodTranslation = [recognizer translationInView:_topDownRodView.superview];
    [recognizer setTranslation:CGPointZero inView:_topDownRodView.superview];

    CGRect newRodFrame = CGRectOffset(_topDownRodView.frame, rodTranslation.x, rodTranslation.y);
    CGFloat upDownViewLeftEdge = CGRectGetMinX(self.upDownView.frame);
    if (CGRectGetMaxX(newRodFrame) > upDownViewLeftEdge) {
        newRodFrame.origin.x = upDownViewLeftEdge - CGRectGetWidth(newRodFrame);
        _haltTrackingRodViewX = YES;
    } else if (_haltTrackingRodViewX) {
        // wait to update the rod's x position
        // until the user's finger aligns with the rod again
        CGPoint recognizerLocation = [recognizer locationInView:self.view];
        if (recognizerLocation.x > _topDownRodView.center.x) {
            newRodFrame.origin.x = _topDownRodView.frame.origin.x;
        } else {
            _haltTrackingRodViewX = NO;
        }
    }

    _topDownRodView.frame = newRodFrame;

    [self updateRodPosition];
}

- (void)frontBackRodDragged:(UIPanGestureRecognizer *)recognizer {
    // update position of rod along up-down view's y axis
    CGPoint rodTranslation = [recognizer translationInView:_frontBackRodView.superview];
    [recognizer setTranslation:CGPointZero inView:_frontBackRodView.superview];

    CGRect newRodFrame = CGRectOffset(_frontBackRodView.frame, 0.0f, rodTranslation.y);
    _frontBackRodView.frame = newRodFrame;

    [self updateRodPosition];
}

- (void)updateRodPosition {
    // update position
    BBRodPosition newRodPos = {BBRodPositionXNone, BBRodPositionYNone, BBRodPositionZBack};
    if (_topDownRodView.center.y > CGRectGetMaxY(self.fenceView.frame)) {
        newRodPos.zPos = BBRodPositionZFront;
    }

    // x, y positions can only assume non-default values if the rod is front
    if (newRodPos.zPos == BBRodPositionZFront) {
        CGPoint topDownRodCenter = _topDownRodView.center;
        if (CGRectContainsPoint(self.rodLeftView.frame, topDownRodCenter)) {
            newRodPos.xPos = BBRodPositionXLeft;
        } else if (CGRectContainsPoint(self.rodMiddleView.frame, topDownRodCenter)) {
            newRodPos.xPos = BBRodPositionXMiddle;
        } else if (CGRectContainsPoint(self.rodRightView.frame, topDownRodCenter)) {
            newRodPos.xPos = BBRodPositionXRight;
        }

        CGPoint frontBackRodCenter = _frontBackRodView.center;
        if (CGRectContainsPoint(self.rodUpView.frame, frontBackRodCenter)) {
            newRodPos.yPos = BBRodPositionYUp;
        } else if (CGRectContainsPoint(self.rodDownView.frame, frontBackRodCenter)) {
            newRodPos.yPos = BBRodPositionYDown;
        }
    }

    // generate notifications
    if (newRodPos.zPos != _rodPosition.zPos) {
        NSLog(@"z pos changed: %u", newRodPos.zPos);
    }
    if (newRodPos.xPos != _rodPosition.xPos) {
        NSLog(@"x pos changed: %u", newRodPos.xPos);
    }
    if (newRodPos.yPos != _rodPosition.yPos) {
        NSLog(@"y pos changed: %u", newRodPos.yPos);
    }

    _rodPosition = newRodPos;
}

@end
