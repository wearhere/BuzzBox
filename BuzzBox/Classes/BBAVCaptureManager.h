//
//  BBAVCaptureManager.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface BBAVCaptureManager : NSObject

@property (nonatomic, readonly) AVCaptureSession *session;

- (BOOL)setupSession;

@end
