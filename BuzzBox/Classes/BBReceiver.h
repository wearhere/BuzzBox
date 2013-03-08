//
//  BBReceiver.h
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBReceiver : NSObject

- (instancetype)initWithMessageService:(NSNetService *)service;

- (BOOL)start;

- (void)registerMessageReceived:(NSString *)message handler:(void (^)(void))handler;

@end
