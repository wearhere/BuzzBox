//
//  BBWizardViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBWizardViewController.h"
#import "BBSender.h"

@interface BBWizardViewController ()

@end

@implementation BBWizardViewController {
    BBSender *_sender;

    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_nextClipGestureRecognizer;
}

- (id)initWithSender:(BBSender *)sender {
    self = [super init];
    if (self) {
        NSParameterAssert(sender);
        _sender = sender;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _toggleClipGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleClip)];
    [self.view addGestureRecognizer:_toggleClipGestureRecognizer];

    _nextClipGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextClip)];
    _nextClipGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:_nextClipGestureRecognizer];
}

- (void)nextClip {
    [_sender sendMessage:@"nextClip"];
}

- (void)toggleClip {
    [_sender sendMessage:@"toggleClip"];
}

@end
