//
//  BBConfigurationViewController.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BBConfigurationViewControllerDelegate;
@interface BBConfigurationViewController : UIViewController

- (instancetype)initWithDelegate:(id<BBConfigurationViewControllerDelegate>)delegate;

- (void)showActivityIndicator;
- (void)hideActivityIndicator;

@end

@protocol BBConfigurationViewControllerDelegate <NSObject>
- (void)configurationViewControllerDidSelectProjection:(BBConfigurationViewController *)viewController;
- (void)configurationViewControllerDidSelectWizard:(BBConfigurationViewController *)viewController;
@end
