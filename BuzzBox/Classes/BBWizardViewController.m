//
//  BBWizardViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBWizardViewController.h"
#import "BBSender.h"

@interface BBWizardViewController () <UIGestureRecognizerDelegate>

@end

@implementation BBWizardViewController {
    BBSender *_sender;

    UITapGestureRecognizer *_toggleInterfaceGestureRecognizer;
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_nextClipGestureRecognizer;
}

- (id)initWithSender:(BBSender *)sender {
    self = [super init];
    if (self) {
#if !DEBUGGING_WIZARD_VIEW
        NSParameterAssert(sender);
#endif
        _sender = sender;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _toggleInterfaceGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleInterface)];
    _toggleInterfaceGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleInterfaceGestureRecognizer];

    _toggleClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleClip)];
    _toggleClipGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_toggleClipGestureRecognizer];

    _nextClipGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextClip)];
    _nextClipGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:_nextClipGestureRecognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL touchIsInLeftHalf = ([touch locationInView:self.view].x < CGRectGetMidX(self.view.bounds));
    if (gestureRecognizer == _toggleInterfaceGestureRecognizer) {
        return touchIsInLeftHalf;
    } else if (gestureRecognizer == _toggleClipGestureRecognizer) {
        return !touchIsInLeftHalf;
    } else {
        return YES;
    }
}

- (void)nextClip {
    [_sender sendMessage:@"nextClip"];
}

- (void)toggleInterface {
    [_sender sendMessage:@"toggleInterface"];
}

- (void)toggleClip {
    [_sender sendMessage:@"toggleClip"];
}

@end
