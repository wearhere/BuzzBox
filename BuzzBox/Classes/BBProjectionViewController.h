//
//  BBProjectionViewController.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface BBProjectionViewController : UIViewController

- (instancetype)initWithAVCaptureSession:(AVCaptureSession *)session;

@end
