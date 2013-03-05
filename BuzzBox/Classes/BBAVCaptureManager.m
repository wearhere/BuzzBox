//
//  BBAVCaptureManager.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBAVCaptureManager.h"

@interface BBAVCaptureManager ()

@property (nonatomic, readwrite) AVCaptureSession *session;
@property (nonatomic, readonly) AVCaptureDevice *backFacingCamera;

@end

@implementation BBAVCaptureManager
@synthesize backFacingCamera = _backFacingCamera;

- (BOOL)setupSession {
    if (self.session) return YES;

    // Set torch and flash mode to auto
	if ([self.backFacingCamera hasFlash]) {
		if ([self.backFacingCamera lockForConfiguration:nil]) {
			if ([self.backFacingCamera isFlashModeSupported:AVCaptureFlashModeAuto]) {
				[self.backFacingCamera setFlashMode:AVCaptureFlashModeAuto];
			}
			[self.backFacingCamera unlockForConfiguration];
		}
	}
	if ([self.backFacingCamera hasTorch]) {
		if ([self.backFacingCamera lockForConfiguration:nil]) {
			if ([self.backFacingCamera isTorchModeSupported:AVCaptureTorchModeAuto]) {
				[self.backFacingCamera setTorchMode:AVCaptureTorchModeAuto];
			}
			[self.backFacingCamera unlockForConfiguration];
		}
	}

    // Init the device input
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.backFacingCamera error:nil];

    // Create the session
    AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
    if ([newCaptureSession canAddInput:newVideoInput]) {
        [newCaptureSession addInput:newVideoInput];
    }

    self.session = newCaptureSession;
    return YES;
}

#pragma mark -

- (AVCaptureDevice *)backFacingCamera {
    if (!_backFacingCamera) {
        for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if (device.position == AVCaptureDevicePositionBack) {
                _backFacingCamera = device;
                break;
            }
        }
    }
    return _backFacingCamera;
}

@end
