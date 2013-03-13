//
//  BBTitleLabel.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/13/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBTitleLabel.h"

@implementation BBTitleLabel

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.shadowColor = [UIColor blackColor];
        self.shadowOffset = CGSizeMake(0.0, 2.25f);
    }
    return self;
}

@end
