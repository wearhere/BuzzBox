//
//  BBWizardViewController.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>


#define DEBUGGING_WIZARD_VIEW 0
#define AUTO_RETRY 1

typedef NS_ENUM(NSUInteger, BBRodPositionX) {
    BBRodPositionXNone,
    BBRodPositionXLeft,
    BBRodPositionXCenter,
    BBRodPositionXRight
};

typedef NS_ENUM(NSUInteger, BBRodPositionY) {
    BBRodPositionYNone,
    BBRodPositionYUp,
    BBRodPositionYMiddle,
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

@class BBSender;
@interface BBWizardViewController : UIViewController

- (instancetype)initWithSender:(BBSender *)sender;

@end
