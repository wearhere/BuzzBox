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

@class BBSender;
@interface BBWizardViewController : UIViewController

- (instancetype)initWithSender:(BBSender *)sender;

@end
