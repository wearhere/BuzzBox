//
//  BBConfigurationViewController.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBConfigurationViewController.h"
#import "BBAVCaptureManager.h"
#import "BBProjectionViewController.h"
#import "BBWizardViewController.h"
#import "BBSender.h"
#import "BBReceiver.h"

@interface BBConfigurationViewController () <BBReceiverDelegate, BBSenderDelegate, NSNetServiceBrowserDelegate>
@property (weak, nonatomic) IBOutlet UIButton *projectionButton;
@property (weak, nonatomic) IBOutlet UIButton *wizardButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@end

@implementation BBConfigurationViewController {
    BBAVCaptureManager *_avCaptureManager;

    NSNetServiceBrowser *_senderBrowser;
    BBSender *_sender;
    UIViewController *_mainViewController;
}

- (id)init {
    self = [super init];
    if (self) {
        _avCaptureManager = [[BBAVCaptureManager alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.activityIndicatorView.hidesWhenStopped = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (![_avCaptureManager setupSession]) {
        NSLog(@"Could not setup recording session.");
        abort();
    }
    // Start the session.
    // This is done asychronously since -startRunning doesn't return until the session is running.
    // This is done upon startup so that the camera will be ready for the background view controller.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_avCaptureManager.session startRunning];
    });
}

- (IBAction)projectionSelected:(id)sender {
    self.projectionButton.hidden = YES;
    self.wizardButton.hidden = YES;

    [self showActivityIndicator];

    // don't wait for a wizard to attach to a projection in the simulator
    // --the projection won't fully work in the simulator anyway;
    // we're most likely looking to debug the projection's view
#if TARGET_IPHONE_SIMULATOR
    _mainViewController = [[BBProjectionViewController alloc] initWithAVCaptureSession:_avCaptureManager.session receiver:nil];
    _mainViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:_mainViewController animated:YES completion:nil];
#else
    _senderBrowser = [[NSNetServiceBrowser alloc] init];
    _senderBrowser.delegate = self;
    [_senderBrowser searchForServicesOfType:[BBSender serviceType] inDomain:@""];
#endif
}

- (IBAction)wizardSelected:(id)sender {
    self.projectionButton.hidden = YES;
    self.wizardButton.hidden = YES;

    [self showActivityIndicator];

    _sender = [[BBSender alloc] init];
    _sender.delegate = self;
    [_sender start];
}

- (void)showActivityIndicator {
    [self.activityIndicatorView startAnimating];
}

- (void)hideActivityIndicator {
    [self.activityIndicatorView stopAnimating];
}

#pragma mark - NSNetServiceBrowser Delegate Methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [aNetServiceBrowser stop];

    [self hideActivityIndicator];

    // dispatch_async to let activity indicator hide
    dispatch_async(dispatch_get_main_queue(), ^{
        BBReceiver *receiver = [[BBReceiver alloc] initWithMessageService:aNetService];
        receiver.delegate = self;   // to receive error notifications
        [receiver start];

        _mainViewController = [[BBProjectionViewController alloc] initWithAVCaptureSession:_avCaptureManager.session receiver:receiver];
        _mainViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self presentViewController:_mainViewController animated:YES completion:nil];
    });
}

#pragma mark - BBReceiver Delegate Methods

- (void)receiverCouldNotConnectToSender:(BBReceiver *)receiver {
    [[[UIAlertView alloc] initWithTitle:@"Could Not Connect to Wizard"
                                message:@"App will retry."
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];

    // show the activity indicator until we reconnect
    [self showActivityIndicator];

    // dispatch_async to let activity indicator show
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_mainViewController) {
            [self dismissViewControllerAnimated:YES completion:^{
                _mainViewController = nil;
                [_senderBrowser searchForServicesOfType:[BBSender serviceType] inDomain:@""];
            }];
        } else {
            [_senderBrowser searchForServicesOfType:[BBSender serviceType] inDomain:@""];
        }
    });
}

- (void)receiverLostConnectionToSender:(BBReceiver *)receiver {
    [[[UIAlertView alloc] initWithTitle:@"Lost Connection to Wizard"
                                message:@"App will retry."
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];

    // show the activity indicator until we reconnect
    [self showActivityIndicator];

    // dispatch_async to let activity indicator show
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_mainViewController) {
            [self dismissViewControllerAnimated:YES completion:^{
                _mainViewController = nil;
                [_senderBrowser searchForServicesOfType:[BBSender serviceType] inDomain:@""];
            }];
        } else {
            [_senderBrowser searchForServicesOfType:[BBSender serviceType] inDomain:@""];
        }
    });
}

#pragma mark - BBSender Delegate Methods

- (void)senderCouldNotConnectToReceiver:(BBSender *)sender {
    // recreate/restart sender
    _sender = [[BBSender alloc] init];
    _sender.delegate = self;
    [_sender start];
}

- (void)senderDidConnectToReceiver:(BBSender *)sender {
    [self hideActivityIndicator];

    // dispatch_async to let activity indicator hide
    dispatch_async(dispatch_get_main_queue(), ^{
        _mainViewController = [[BBWizardViewController alloc] initWithSender:_sender];

        _mainViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self presentViewController:_mainViewController animated:YES completion:nil];
    });
}

- (void)senderLostConnectionToReceiver:(BBSender *)sender {
    [[[UIAlertView alloc] initWithTitle:@"Lost Connection to Projection"
                                message:@"App will retry."
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];

    // show the activity indicator until we reconnect
    [self showActivityIndicator];

    // dispatch_async to let activity indicator show
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_mainViewController) {
            [self dismissViewControllerAnimated:YES completion:^{
                _mainViewController = nil;
            }];
        }
    });
}

@end
