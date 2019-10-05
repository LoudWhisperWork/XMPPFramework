#import <Foundation/Foundation.h>
#import "XMPP.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPInbox: XMPPModule

- (void)discoverInboxMessages;
- (NSInteger)unreadMessagesCountForChatJID:(XMPPJID *)chatJID;
- (nullable NSString *)unreadMessageIdentifierFromWhichCountingStartsForChatJID:(XMPPJID *)chatJID;

@end


@protocol XMPPInboxDelegate <NSObject>
@optional

- (void)xmppInbox:(XMPPInbox *)inbox didDiscoverInboxMessages:(NSArray<XMPPMessage *> *)messages
NS_SWIFT_NAME(xmppInbox(_:didDiscoverInboxMessages:));

- (void)xmppInbox:(XMPPInbox *)inbox didFailToDiscoverInboxMessages:(NSError *)error
NS_SWIFT_NAME(xmppInbox(_:didFailToDiscoverInboxMessages:));

- (void)xmppInbox:(XMPPInbox *)inbox didUpdateInboxMessagesForChatWithJabberIdentifier:(XMPPJID *)jid
NS_SWIFT_NAME(xmppInbox(_:didUpdateInboxMessagesForChatWithJabberIdentifier:));

@end

NS_ASSUME_NONNULL_END
