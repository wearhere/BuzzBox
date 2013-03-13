//
//  BBProjectionIntroView.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/13/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBProjectionIntroView.h"
#import "BBTitleLabel.h"

#import <QuartzCore/QuartzCore.h>


static const CGFloat kIntroLabelMargin = 20.0f;

static const NSTimeInterval kCountdownDuration = 3.0;

@interface BBIntroLabel : UIView
- (void)countDownWithDuration:(NSTimeInterval)duration;
@end

@interface BBIntroLabel ()
@property (nonatomic, readonly) CAShapeLayer *shapeLayer;
@end

@implementation BBIntroLabel {
    BBTitleLabel *_label;
}

+ (Class)layerClass {
    return [CAShapeLayer class];
}

- (CAShapeLayer *)shapeLayer {
    return (CAShapeLayer *)self.layer;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        self.shapeLayer.cornerRadius = 8.0f;
        self.shapeLayer.strokeColor = [[UIColor colorWithRed:40.0f/255.0f
                                                       green:135.0f/255.0f
                                                        blue:170.0f/255.0f
                                                       alpha:1.0f] CGColor];
        self.shapeLayer.fillColor = self.backgroundColor.CGColor;

        _label = [[BBTitleLabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = self.backgroundColor;
        _label.opaque = self.opaque;
        _label.font = [UIFont fontWithName:@"ApexNew-Medium" size:20.0f];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.numberOfLines = 2;
        _label.text = @"Welcome to BuzzBox!\nLet's get started.";
        [self addSubview:_label];
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGRect boundsRect = (CGRect){CGPointZero, size};
    CGRect contentRect = CGRectInset(boundsRect, kIntroLabelMargin, kIntroLabelMargin);
    CGSize sizeThatFitsLabel = [_label sizeThatFits:contentRect.size];
    CGRect rectThatFitsLabel = (CGRect){CGPointZero, sizeThatFitsLabel};
    CGRect rectThatFits = CGRectInset(rectThatFitsLabel, -kIntroLabelMargin, -kIntroLabelMargin);
    return rectThatFits.size;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.shapeLayer.path = [[UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:self.shapeLayer.cornerRadius] CGPath];
    _label.frame = CGRectInset(self.bounds, kIntroLabelMargin, kIntroLabelMargin);
}

- (void)countDownWithDuration:(NSTimeInterval)duration {
    CABasicAnimation *strokeAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    strokeAnimation.duration = duration;
    strokeAnimation.fromValue = @(self.shapeLayer.strokeEnd);
    self.shapeLayer.strokeEnd = 0.0;
    [self.shapeLayer addAnimation:strokeAnimation forKey:@"strokeEnd"];
}

@end


@implementation BBProjectionIntroView {
    BBIntroLabel *_introLabel;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _introLabel = [[BBIntroLabel alloc] initWithFrame:CGRectZero];
        [self addSubview:_introLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [_introLabel sizeToFit];
    _introLabel.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

- (void)countDownWithCompletion:(void (^)(void))completionHandler {
    [_introLabel countDownWithDuration:kCountdownDuration];
    
    BBProjectionIntroView *__weak weakSelf = self;
    double delayInSeconds = kCountdownDuration;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        BBProjectionIntroView *strongSelf = weakSelf;
        if (strongSelf) {
            if (completionHandler) completionHandler();
        }
    });
}

@end
