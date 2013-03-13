//
//  BBTitleLabel.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/13/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBTitleLabel.h"

@implementation BBTitleLabel

- (void)drawTextInRect:(CGRect)rect {
    CGSize shadowOffset = self.shadowOffset;
    UIColor *textColor = self.textColor;

    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(c, 1);
    CGContextSetLineJoin(c, kCGLineJoinRound);

    CGContextSetTextDrawingMode(c, kCGTextStroke);
    self.textColor = [UIColor blackColor];
    [super drawTextInRect:rect];

    CGContextSetTextDrawingMode(c, kCGTextFill);
    self.textColor = textColor;
    self.shadowOffset = CGSizeMake(0, 0);
    [super drawTextInRect:rect];

    self.shadowOffset = shadowOffset;
}

@end
