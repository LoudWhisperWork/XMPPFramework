//
//  XMPPInbox.h
//  XMPPFramework
//
//  Created by Daniil Gavrilov on 04/10/2019.
//  Copyright © 2019 XMPPFramework. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPP.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPInbox : XMPPModule

- (void)discoverInboxMessages;

@end


@protocol XMPPInboxDelegate <NSObject>
@optional

- (void)xmppInbox:(XMPPInbox *)inbox didReceiveChatMessage:(XMPPMessage *)message
NS_SWIFT_NAME(xmppInbox(_:didReceiveChatMessage:));

- (void)xmppInbox:(XMPPInbox *)inbox didSendChatMessage:(XMPPMessage *)message
NS_SWIFT_NAME(xmppInbox(_:didSendChatMessage:));

@end

NS_ASSUME_NONNULL_END
