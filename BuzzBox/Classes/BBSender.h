//
//  BBSender.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol BBSenderDelegate;
@interface BBSender : NSObject

@property (nonatomic, weak) id<BBSenderDelegate> delegate;

+ (NSString *)serviceType;

- (BOOL)start;

- (void)sendMessage:(NSString *)message;

@end


@protocol BBSenderDelegate <NSObject>
@required
- (void)receiverDidConnectToSender:(BBSender *)sender;
@end
