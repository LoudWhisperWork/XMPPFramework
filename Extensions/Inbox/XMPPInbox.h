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

@interface XMPPInbox: XMPPModule

- (void)discoverInboxMessages;

@end


@protocol XMPPInboxDelegate <NSObject>
@optional

- (void)xmppInbox:(XMPPInbox *)inbox didDiscoverInboxMessages:(XMPPMessage *)message
NS_SWIFT_NAME(xmppInbox(_:didDiscoverInboxMessages:));

- (void)xmppInbox:(XMPPInbox *)inbox didFailToDiscoverInboxMessages:(NSError *)error
NS_SWIFT_NAME(xmppInbox(_:didFailToDiscoverInboxMessages:));

@end

NS_ASSUME_NONNULL_END
