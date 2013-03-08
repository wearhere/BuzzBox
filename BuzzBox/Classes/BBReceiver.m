//
//  BBReceiver.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBReceiver.h"
#import "Connection.h"
#import "BBMessageProtocol.h"


@interface BBReceiver () <ConnectionDelegate>
@end


@implementation BBReceiver {
    Connection *_senderConnection;
    NSMutableDictionary *_handlers;
}

- (instancetype)initWithMessageService:(NSNetService *)service {
    self = [super init];
    if (self) {
        NSParameterAssert(service);
        _senderConnection = [[Connection alloc] initWithNetService:service];
        _handlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)start {
    if (!_senderConnection) {
        return NO;
    }

    _senderConnection.delegate = self;
    return [_senderConnection connect];
}

- (void)stop {
    [_senderConnection close];
    _senderConnection = nil;
}

- (void)registerMessageReceived:(NSString *)message handler:(void (^)(void))handler {
    _handlers[message] = [handler copy];
}

#pragma mark - ConnectionDelegate Method Implementations

- (void)connectionAttemptFailed:(Connection*)connection {
    [[[UIAlertView alloc] initWithTitle:@"Could Not Connect to Wizard"
                                message:@"Please restart the app to try again."
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
}

- (void)connectionTerminated:(Connection*)connection {
    [[[UIAlertView alloc] initWithTitle:@"Lost Connection to Wizard"
                                message:@"Please restart the app to try again."
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
}

- (void)receivedNetworkPacket:(NSDictionary*)packet viaConnection:(Connection*)connection {
    NSString *messageName = packet[BBMessageName];
    void(^handler)(void) = _handlers[messageName];
    if (handler) {
        handler();
    }
}

@end
