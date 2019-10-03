#import <Foundation/Foundation.h>
#import "XMPPElement.h"

/**
 * The XMPPMessage class represents a <message> element.
 * It extends XMPPElement, which in turn extends NSXMLElement.
 * All <message> elements that go in and out of the
 * xmpp stream will automatically be converted to XMPPMessage objects.
 * 
 * This class exists to provide developers an easy way to add functionality to message processing.
 * Simply add your own category to XMPPMessage to extend it with your own custom methods.
**/

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageModel : NSObject

- (instancetype)initWithIdentifier:(nonnull NSString *)identifier originalIdentifier:(nullable NSString *)originalIdentifier sender:(nonnull NSString *)sender recipient:(nonnull NSString *)recipient text:(nonnull NSString *)text date:(nonnull NSDate *)date archiveIdentifier:(nullable NSString *)archiveIdentifier previousArchiveIdentifier:(nullable NSString *)previousArchiveIdentifier outgoing:(BOOL)outgoing system:(BOOL)system;

@property (nonatomic, readonly, nonnull) NSString *identifier;
@property (nonatomic, readonly, nullable) NSString *originalIdentifier;
@property (nonatomic, readonly, nonnull) XMPPJID *sender;
@property (nonatomic, readonly, nonnull) NSString *recipient;
@property (nonatomic, readonly, nonnull) NSString *text;
@property (nonatomic, readonly, nonnull) NSDate *date;
@property (nonatomic, readonly, nullable) NSString *archiveIdentifier;
@property (nonatomic, readonly, nullable) NSString *previousArchiveIdentifier;
@property (nonatomic, readonly) BOOL isOutgoing;
@property (nonatomic, readonly) BOOL isSystem;

@end

@interface XMPPMessage : XMPPElement

// Converts an NSXMLElement to an XMPPMessage element in place (no memory allocations or copying)
+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element;

+ (XMPPMessage *)message;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type to:(nullable XMPPJID *)to;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type elementID:(nullable NSString *)eid;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
+ (XMPPMessage *)messageWithType:(nullable NSString *)type child:(nullable NSXMLElement *)childElement;

- (instancetype)init;
- (instancetype)initWithType:(nullable NSString *)type;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)to;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid;
- (instancetype)initWithType:(nullable NSString *)type to:(nullable XMPPJID *)jid elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
- (instancetype)initWithType:(nullable NSString *)type elementID:(nullable NSString *)eid;
- (instancetype)initWithType:(nullable NSString *)type elementID:(nullable NSString *)eid child:(nullable NSXMLElement *)childElement;
- (instancetype)initWithType:(nullable NSString *)type child:(nullable NSXMLElement *)childElement;

@property (nonatomic, readonly, nullable) NSString *type;
@property (nonatomic, readonly, nullable) NSString *subject;
@property (nonatomic, readonly, nullable) NSString *thread;
@property (nonatomic, readonly, nullable) NSString *body;
- (nullable NSString *)bodyForLanguage:(NSString *)language;

- (void)addSubject:(NSString *)subject;
- (void)addBody:(NSString *)body;
- (void)addBody:(NSString *)body withLanguage:(NSString *)language;
- (void)addThread:(NSString *)thread;

@property (nonatomic, readonly) BOOL isChatMessage;
@property (nonatomic, readonly) BOOL isChatMessageWithBody;
@property (nonatomic, readonly) BOOL isErrorMessage;
@property (nonatomic, readonly) BOOL isMessageWithBody;

@property (nonatomic, readonly, nullable) NSError *errorMessage;

@end
NS_ASSUME_NONNULL_END
