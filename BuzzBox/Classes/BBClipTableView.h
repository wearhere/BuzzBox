//
//  BBClipTableView.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/11/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>

extern const CGFloat kRowSwapAnimationDuration;

@interface BBClipTableView : UIView

- (void)previousRow;
- (void)nextRow;

@end
