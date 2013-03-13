//
//  BBProjectionViewController.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define DEBUGGING_PROJECTION_VIEW 0

@class BBReceiver;
@interface BBProjectionViewController : UIViewController

- (instancetype)initWithAVCaptureSession:(AVCaptureSession *)session
                                receiver:(BBReceiver *)receiver;

@end
