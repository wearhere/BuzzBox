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

- (void)sendMessage:(NSString *)message args:(NSArray *)args;

@end


@protocol BBSenderDelegate <NSObject>
@required
- (void)senderCouldNotConnectToReceiver:(BBSender *)sender;
- (void)senderDidConnectToReceiver:(BBSender *)sender;
- (void)senderLostConnectionToReceiver:(BBSender *)sender;
@end
