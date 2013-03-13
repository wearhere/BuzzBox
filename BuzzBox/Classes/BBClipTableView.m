//
//  BBClipTableView.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/11/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBClipTableView.h"

#import <AVFoundation/AVFoundation.h>


static const CGSize kSelectedClipSize = (CGSize){280.0f, 280.0f};
static const CGFloat kClipCornerRadius = 8.0f;
static const CGFloat kClipFrameBorderWidth = 5.0f;


typedef NS_ENUM(NSUInteger, BBClipPosition) {
    BBClipPositionLeft,
    BBClipPositionCenter,
    BBClipPositionRight
};


@interface BBClipLayer : CAShapeLayer
@property (nonatomic) BOOL selected;
- (instancetype)initWithClip:(NSString *)clipPath position:(BBClipPosition)position;
@end

@implementation BBClipLayer {
    CALayer *_clipClippingLayer;
    AVPlayerLayer *_clip;
}

- (instancetype)initWithClip:(NSString *)clipPath position:(BBClipPosition)position {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor].CGColor;
        self.opaque = NO;
        self.cornerRadius = 8.0f;
        self.shadowOpacity = 0.5f;
        self.shadowOffset = CGSizeMake(0.0f, 4.5f);
        self.shadowRadius = 1.5;
        self.lineWidth = 10.0f;
        self.strokeColor = [[UIColor clearColor] CGColor];
        self.fillColor = self.backgroundColor;

        _clipClippingLayer = [CALayer layer];
        _clipClippingLayer.backgroundColor = self.backgroundColor;
        _clipClippingLayer.opaque = self.opaque;
        _clipClippingLayer.cornerRadius = self.cornerRadius;
        _clipClippingLayer.masksToBounds = YES;
        [self addSublayer:_clipClippingLayer];

        _clip = [AVPlayerLayer layer];
        _clip.backgroundColor = _clipClippingLayer.backgroundColor;
        _clip.opaque = _clipClippingLayer.opaque;

        NSURL *clipURL = [NSURL fileURLWithPath:clipPath];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:clipURL];
        _clip.player = [AVPlayer playerWithPlayerItem:playerItem];
        _clip.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [_clipClippingLayer addSublayer:_clip];

        CGPoint anchorPoint;
        switch (position) {
            case BBClipPositionLeft:
                anchorPoint = CGPointMake(0.0, 0.5);
                break;
            case BBClipPositionCenter:
                anchorPoint = CGPointMake(0.5, 0.5);
                break;
            case BBClipPositionRight:
                anchorPoint = CGPointMake(1.0, 0.5);
                break;
        }
        self.anchorPoint = anchorPoint;
    }
    return self;
}

- (void)layoutSublayers {
    [super layoutSublayers];
    self.path = [[UIBezierPath bezierPathWithRoundedRect:self.bounds
                                            cornerRadius:self.cornerRadius] CGPath];
    _clipClippingLayer.bounds = self.bounds;
    _clipClippingLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _clip.bounds = (CGRect){_clipClippingLayer.bounds.origin,
                            CGSizeMake(CGRectGetWidth(_clipClippingLayer.bounds),
                                       CGRectGetHeight(_clipClippingLayer.bounds) + 2.0f)};
    _clip.position = CGPointMake(CGRectGetMidX(_clipClippingLayer.bounds), CGRectGetMidY(_clipClippingLayer.bounds));
}

- (void)setSelected:(BOOL)selected {
    if (selected != _selected) {
        _selected = selected;
        if (!selected) [_clip.player pause];
        
        CABasicAnimation *boundsAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
        CABasicAnimation *clippingBoundsAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
        CABasicAnimation *clippingPositionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
        CABasicAnimation *clipBoundsAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
        CABasicAnimation *clipPositionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
        CABasicAnimation *strokeAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
        boundsAnimation.duration = clippingBoundsAnimation.duration = clipBoundsAnimation.duration =
            clippingPositionAnimation.duration = clipPositionAnimation.duration =
            pathAnimation.duration = 0.3;
        strokeAnimation.duration = 0.6;
        strokeAnimation.delegate = self;

        CGRect bounds;
        CGColorRef strokeColor;
        if (selected) {
            bounds = (CGRect){CGPointZero, kSelectedClipSize};
            strokeColor = CGColorCreateCopy([[UIColor colorWithRed:40.0f/255.0f
                                                             green:135.0f/255.0f
                                                              blue:170.0f/255.0f
                                                             alpha:1.0f] CGColor]);
        } else {
            bounds = self.superlayer.bounds;
            strokeColor = CGColorCreateCopy([[UIColor clearColor] CGColor]);
        }

        boundsAnimation.fromValue = [NSValue valueWithCGRect:self.bounds];
        pathAnimation.fromValue = (__bridge id)(self.path);
        clippingBoundsAnimation.fromValue = [NSValue valueWithCGRect:_clipClippingLayer.bounds];
        clipPositionAnimation.fromValue = [NSValue valueWithCGPoint:_clipClippingLayer.position];
        clipBoundsAnimation.fromValue = [NSValue valueWithCGRect:_clip.bounds];
        clipPositionAnimation.fromValue = [NSValue valueWithCGPoint:_clip.position];

        self.bounds = bounds;
        [self setNeedsLayout];
        [self layoutIfNeeded];
        
        [self addAnimation:boundsAnimation forKey:@"bounds"];
        [_clipClippingLayer addAnimation:boundsAnimation forKey:@"bounds"];
        [_clipClippingLayer addAnimation:clippingPositionAnimation forKey:@"position"];
        [_clip addAnimation:boundsAnimation forKey:@"bounds"];
        [_clip addAnimation:clipPositionAnimation forKey:@"position"];

        [self addAnimation:pathAnimation forKey:@"path"];

        strokeAnimation.fromValue = (__bridge id)(self.strokeColor);
        self.strokeColor = strokeColor;
        CFRelease(strokeColor);
        [self addAnimation:strokeAnimation forKey:@"strokeColor"];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if ([anim isKindOfClass:[CABasicAnimation class]] &&
        [((CABasicAnimation *)anim).keyPath isEqualToString:@"strokeColor"] && _selected) {
        [_clip.player play];
    }
}

@end


@protocol BBClipViewDelegate <NSObject>
@required
- (void)clipView:(BBClipView *)clipView willSetSelected:(BOOL)selected;
@end

@interface BBClipView ()
@property (nonatomic, weak) id<BBClipViewDelegate> delegate;
- (instancetype)initWithClip:(NSString *)clipPath position:(BBClipPosition)position;
@end

@implementation BBClipView {
    BBClipLayer *_clipLayer;

    UITapGestureRecognizer *_toggleSelectedRecognizer;
    BOOL _selected;
}

- (instancetype)initWithClip:(NSString *)clipPath position:(BBClipPosition)position {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.layer.backgroundColor = [UIColor clearColor].CGColor;
        self.layer.opaque = NO;

        _clipLayer = [[BBClipLayer alloc] initWithClip:clipPath position:position];
        [self.layer addSublayer:_clipLayer];

        _toggleSelectedRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSelected)];
        [self addGestureRecognizer:_toggleSelectedRecognizer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (!_selected) {
        _clipLayer.frame = self.layer.bounds;
    }
}

- (void)setSelected:(BOOL)selected {
    if (selected != _selected) {
        [self.delegate clipView:self willSetSelected:selected];
        _selected = selected;
        _clipLayer.selected = selected;
    }
}

- (void)toggleSelected {
    [self setSelected:!_selected];
}

@end


static const CGFloat kClipMargin = 20.0f;
static const NSUInteger kNumClips = 3;

@interface BBClipTableRowView () <BBClipViewDelegate>
@property (nonatomic, strong) BBClipView *selectedClip;
+ (CGSize)sizeThatFits:(CGSize)size;
- (instancetype)initWithClipCollection:(NSString *)collectionName;
@end

@implementation BBClipTableRowView {
    NSArray *_clips;
}

+ (CGSize)sizeThatFits:(CGSize)size {
    CGFloat clipWidth = (size.width - (kNumClips + 1) * kClipMargin) / kNumClips;
    return CGSizeMake(size.width, clipWidth + 2 * kClipMargin);
}

- (instancetype)initWithClipCollection:(NSString *)collectionName {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        NSArray *clipPaths = [[NSBundle mainBundle] pathsForResourcesOfType:nil inDirectory:collectionName];
        NSMutableArray *clips = [NSMutableArray arrayWithCapacity:[clipPaths count]];
        BBClipPosition position = BBClipPositionLeft;
        for (NSString *clipPath in clipPaths) {
            BBClipView *clip = [[BBClipView alloc] initWithClip:clipPath position:position];
            clip.layer.zPosition = 0.0f;
            position++;
            clip.delegate = self;
            [self addSubview:clip];
            [clips addObject:clip];
            if ([clips count] == kNumClips) break;
        }
        _clips = [clips copy];
    }
    return self;
}

- (void)layoutSubviews {
    if (_selectedClip) return;
    [super layoutSubviews];

    NSUInteger numClips = [_clips count];
    CGFloat clipWidth = (CGRectGetWidth(self.bounds) - (numClips + 1) * kClipMargin) / numClips;
    CGFloat clipOriginY = (CGRectGetHeight(self.bounds) - clipWidth) / 2.0f;

    CGFloat clipsRightEdge = CGRectGetMinX(self.bounds);
    for (CALayer *clip in _clips) {
        clip.frame = CGRectMake(clipsRightEdge + kClipMargin, clipOriginY, clipWidth, clipWidth);
        clipsRightEdge = CGRectGetMaxX(clip.frame);
    }
}

- (BBClipView *)leftClip {
    return _clips[0];
}

- (BBClipView *)centerClip {
    return _clips[1];
}

- (BBClipView *)rightClip {
    return _clips[2];
}

- (void)setSelectedClip:(BBClipView *)selectedClip {
    if (selectedClip != _selectedClip) {
#if TARGET_IPHONE_SIMULATOR
        // only need to manage selected clips when debugging projection in simulator
        [_selectedClip setSelected:NO];
#endif
        _selectedClip.layer.zPosition = 0.0f;
        _selectedClip = selectedClip;
        _selectedClip.layer.zPosition = 10.0f;
    }
}

- (void)clipView:(BBClipView *)clipView willSetSelected:(BOOL)selected {
    if (selected) self.selectedClip = clipView;
}

@end


const CGFloat kRowSwapAnimationDuration = 0.25;

@implementation BBClipTableView {
    NSArray *_rows;
    NSUInteger _currentRowIndex;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        NSString *clipCollectionsPath = [[NSBundle mainBundle] pathForResource:@"ClipCollections" ofType:@"plist"];
        NSArray *clipCollections = [NSArray arrayWithContentsOfFile:clipCollectionsPath];
        NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[clipCollections count]];
        for (NSString *collectionName in clipCollections) {
            BBClipTableRowView *rowView = [[BBClipTableRowView alloc] initWithClipCollection:collectionName];
            rowView.layer.zPosition = 0.0f;
            [self addSubview:rowView];
            [rows addObject:rowView];
        }
        ((BBClipTableRowView *)rows[0]).layer.zPosition = 10.0f;
        _rows = [rows copy];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGSize rowFitSize = [BBClipTableRowView sizeThatFits:self.bounds.size];
    CGFloat rowHeight = rowFitSize.height;
    CGFloat rowOffset = CGRectGetMidY(self.bounds) - rowFitSize.height/2.0 - rowHeight * _currentRowIndex;
    for (UIView *row in _rows) {
        row.frame = (CGRect){CGPointMake(0.0f, rowOffset), rowFitSize};
        rowOffset += rowHeight;
    }
}

- (BBClipTableRowView *)currentRow {
    return _rows[_currentRowIndex];
}

- (void)previousRow {
    if (_currentRowIndex > 0) {
        self.currentRow.layer.zPosition = 0.0f;
        _currentRowIndex--;
        self.currentRow.layer.zPosition = 10.0f;
        [UIView animateWithDuration:kRowSwapAnimationDuration delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    }
}

- (void)nextRow {
    if (_currentRowIndex < ([_rows count] - 1)) {
        self.currentRow.layer.zPosition = 0.0f;
        _currentRowIndex++;
        self.currentRow.layer.zPosition = 10.0f;
        [UIView animateWithDuration:kRowSwapAnimationDuration delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    }
}

@end
