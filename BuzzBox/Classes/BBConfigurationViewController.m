//
//  BBConfigurationViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBConfigurationViewController.h"
#import "BBProjectionViewController.h"
#import "BBAppDelegate.h"
#import "BBAVCaptureManager.h"

@interface BBConfigurationViewController ()
@property (weak, nonatomic) IBOutlet UIButton *projectionButton;
@property (weak, nonatomic) IBOutlet UIButton *wizardButton;
@end

@implementation BBConfigurationViewController {
    id <BBConfigurationViewControllerDelegate> _delegate;
}

- (instancetype)initWithDelegate:(id<BBConfigurationViewControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (IBAction)projectionSelected:(id)sender {
    [_delegate configurationViewControllerDidSelectProjection:self];
}

- (IBAction)wizardSelected:(id)sender {
    [_delegate configurationViewControllerDidSelectWizard:self];
}

@end
