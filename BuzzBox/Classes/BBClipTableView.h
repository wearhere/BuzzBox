//
//  BBClipTableView.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/11/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface BBClipView : UIView

- (void)setSelected:(BOOL)selected;

@end


@interface BBClipTableRowView : UIView

@property (nonatomic, readonly) BBClipView *leftClip;
@property (nonatomic, readonly) BBClipView *centerClip;
@property (nonatomic, readonly) BBClipView *rightClip;

@end


extern const CGFloat kRowSwapAnimationDuration;

@interface BBClipTableView : UIView

@property (nonatomic, readonly) BBClipTableRowView *currentRow;

- (void)previousRow;
- (void)nextRow;

@end
