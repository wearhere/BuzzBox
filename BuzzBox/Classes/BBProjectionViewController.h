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

extern NSString *const BBInstructionIndexChanged;

@class BBReceiver;
@interface BBProjectionViewController : UIViewController

+ (NSInteger)instructionIndex;

- (instancetype)initWithAVCaptureSession:(AVCaptureSession *)session
                                receiver:(BBReceiver *)receiver;

@end
