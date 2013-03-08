//
//  BBSender.m
//  BuzzBox
//
//  Created by Jeffrey Wear on 3/7/13.
//  Copyright (c) 2013 Jeffrey Wear. All rights reserved.
//

#import "BBSender.h"
#import "Server.h"
#import "Connection.h"
#import "BBMessageProtocol.h"


@interface BBSender () <ServerDelegate, ConnectionDelegate>
@end


@implementation BBSender {
    Server *_messageServer;
    Connection *_receiverConnection;
}

+ (NSString *)serviceType {
    return @"_buzzbox._tcp.";
}

- (id)init {
    self = [super init];
    if (self) {
        _messageServer = [[Server alloc] initWithServiceType:[[self class] serviceType] name:[[UIDevice currentDevice] name]];
        _messageServer.delegate = self;
    }
    return self;
}

- (BOOL)start {
    return [_messageServer start];
}

- (void)stop {
    [_messageServer stop];
    [_receiverConnection close];
}

- (void)sendMessage:(NSString *)message {
    [_receiverConnection sendNetworkPacket:@{ BBMessageName: message }];
}

#pragma mark - ServerDelegate Method Implementations

- (void) serverFailed:(Server*)server reason:(NSString*)reason {
    [[[UIAlertView alloc] initWithTitle:@"Wizard Server Failed"
                                message:[NSString stringWithFormat:@"Due to reason: %@. Please restart the app to try again.", reason]
                               delegate:nil
                      cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
    [self stop];
}

- (void) handleNewConnection:(Connection*)connection {
    // we only handle one receiver
    if (_receiverConnection) return;

    _receiverConnection = connection;
    _receiverConnection.delegate = self;

    [self.delegate receiverDidConnectToSender:self];
}

#pragma mark - ConnectionDelegate Method Implementations

// We won't be initiating connections, so this is not important
- (void) connectionAttemptFailed:(Connection*)connection {
}

// One of the clients disconnected, remove it from our list
- (void) connectionTerminated:(Connection*)connection {
    if (connection == _receiverConnection) {
        _receiverConnection = nil;
    }
}

// We shouldn't be getting messages back
- (void) receivedNetworkPacket:(NSDictionary*)packet viaConnection:(Connection*)connection {
}

@end
