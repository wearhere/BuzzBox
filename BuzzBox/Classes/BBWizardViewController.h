//
//  BBWizardViewController.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>


// set to 1 to launch the wizard (upon selecting "Wizard" on startup)
// without waiting for the projection to connect
#define DEBUGGING_WIZARD_VIEW 0

// after a connection failure, if 0, the app will show an alert prompting to "Abort" or "Retry" connecting
// if 1, the wizard will immediately begin searching for the projection again
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
