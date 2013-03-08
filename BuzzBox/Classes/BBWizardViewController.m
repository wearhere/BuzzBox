//
//  BBWizardViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBWizardViewController.h"

@interface BBWizardViewController ()

@end

@implementation BBWizardViewController {
    UITapGestureRecognizer *_toggleClipGestureRecognizer;
    UISwipeGestureRecognizer *_nextClipGestureRecognizer;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
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
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)toggleClip {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
