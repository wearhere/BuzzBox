//
//  BBAppDelegate.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/4/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBAppDelegate.h"
#import "BBAVCaptureManager.h"
#import "BBBackgroundViewController.h"
#import "BBConfigurationViewController.h"

@interface BBAppDelegate () <BBConfigurationViewControllerDelegate>
@end

@implementation BBAppDelegate {
    BBAVCaptureManager *_avCaptureManager;
    UIViewController *_mainViewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];

    _avCaptureManager = [[BBAVCaptureManager alloc] init];
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

    self.window.rootViewController = [[BBConfigurationViewController alloc] initWithDelegate:self];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)configurationViewControllerDidSelectProjection:(BBConfigurationViewController *)viewController {
    _mainViewController = [[BBBackgroundViewController alloc] initWithAVCaptureSession:_avCaptureManager.session];
    _mainViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self.window.rootViewController presentViewController:_mainViewController animated:YES completion:nil];
}

- (void)configurationViewControllerDidSelectWizard:(BBConfigurationViewController *)viewController {

}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
