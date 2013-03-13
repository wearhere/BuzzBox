//
//  BBClipTableView.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/11/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBClipTableView.h"

#import <AVFoundation/AVFoundation.h>


static const CGFloat kClipMargin = 20.0f;
static const NSUInteger kNumClips = 3;

@interface BBClipView : UIView
- (instancetype)initWithClip:(NSString *)clipPath;
@end

@implementation BBClipView {
    CALayer *_clipBackgroundLayer;
    AVPlayerLayer *_clip;
}

- (instancetype)initWithClip:(NSString *)clipPath {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.layer.cornerRadius = 8.0f;
        self.layer.shadowOpacity = 0.5f;
        self.layer.shadowOffset = CGSizeMake(0.0f, 4.5f);
        self.layer.shadowRadius = 1.5;

        _clipBackgroundLayer = [CALayer layer];
        _clipBackgroundLayer.backgroundColor = self.backgroundColor.CGColor;
        _clipBackgroundLayer.opaque = self.opaque;
        _clipBackgroundLayer.cornerRadius = self.layer.cornerRadius;
        _clipBackgroundLayer.masksToBounds = YES;
        [self.layer addSublayer:_clipBackgroundLayer];

        _clip = [AVPlayerLayer layer];
        _clip.backgroundColor = _clipBackgroundLayer.backgroundColor;
        _clip.opaque = _clipBackgroundLayer.opaque;

        NSURL *clipURL = [NSURL fileURLWithPath:clipPath];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:clipURL];
        _clip.player = [AVPlayer playerWithPlayerItem:playerItem];
        _clip.videoGravity = AVLayerVideoGravityResizeAspectFill;

        [_clipBackgroundLayer addSublayer:_clip];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _clipBackgroundLayer.frame = self.bounds;
    _clip.frame = (CGRect){_clipBackgroundLayer.frame.origin,
                            CGSizeMake(CGRectGetWidth(_clipBackgroundLayer.frame),
                                       CGRectGetHeight(_clipBackgroundLayer.frame) + 2.0f)};
}

@end


@interface BBClipTableRowView : UIView
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
        for (NSString *clipPath in clipPaths) {
            BBClipView *clip = [[BBClipView alloc] initWithClip:clipPath];
            [self addSubview:clip];
            [clips addObject:clip];
            if ([clips count] == kNumClips) break;
        }
        _clips = [clips copy];
    }
    return self;
}

- (void)layoutSubviews {
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

@end


const CGFloat kRowSwapAnimationDuration = 0.25;

@implementation BBClipTableView {
    NSArray *_rows;
    NSUInteger _currentRow;
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
            [self addSubview:rowView];
            [rows addObject:rowView];
        }
        _rows = [rows copy];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGSize rowFitSize = [BBClipTableRowView sizeThatFits:self.bounds.size];
    CGFloat rowHeight = rowFitSize.height;
    CGFloat rowOffset = CGRectGetMidY(self.bounds) - rowFitSize.height/2.0 - rowHeight * _currentRow;
    for (UIView *row in _rows) {
        row.frame = (CGRect){CGPointMake(0.0f, rowOffset), rowFitSize};
        rowOffset += rowHeight;
    }
}

- (void)previousRow {
    if (_currentRow > 0) {
        _currentRow--;
        [UIView animateWithDuration:kRowSwapAnimationDuration delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    }
}

- (void)nextRow {
    if (_currentRow < ([_rows count] - 1)) {
        _currentRow++;
        [UIView animateWithDuration:kRowSwapAnimationDuration delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    }
}

@end
