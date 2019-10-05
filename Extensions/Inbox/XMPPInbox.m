#import "XMPPInbox.h"
#import "XMPPFramework.h"
#import "XMPPIDTracker.h"
#import "NSXMLElement+XEP_0297.h"
#import "XMPPMessage+XEP_0333.h"

NSString *const XMPPInboxIQType = @"set";
NSString *const XMPPInboxDataQueryName = @"x";
NSString *const XMPPInboxFieldQueryName = @"field";
NSString *const XMPPInboxQueryName = @"inbox";
NSString *const XMPPInboxValueQueryName = @"value";
NSString *const XMPPInboxResultQueryName = @"result";

NSString *const XMPPInboxTypeName = @"type";
NSString *const XMPPInboxFieldVariableName = @"var";
NSString *const XMPPInboxQueryIdentifierName = @"queryid";
NSString *const XMPPInboxUnreadName = @"unread";
NSString *const XMPPInboxIdentifierName = @"id";

NSString *const XMPPInboxDataXMLNS = @"jabber:x:data";
NSString *const XMPPInboxXMLNS = @"erlang-solutions.com:xmpp:inbox:0";

NSString *const XMPPInboxDataType = @"form";
NSString *const XMPPInboxFieldFormType = @"FORM_TYPE";
NSString *const XMPPInboxFieldHidden = @"hidden";
NSString *const XMPPInboxFieldTextSingle = @"text-single";
NSString *const XMPPInboxFieldListSingle = @"list-single";
NSString *const XMPPInboxFieldHiddenRead = @"hidden_read";
NSString *const XMPPInboxFieldOrder = @"order";
NSString *const XMPPInboxFieldStart = @"start";
NSString *const XMPPInboxFieldEnd = @"end";

NSString *const XMPPInboxFieldFalseValue = @"false";
NSString *const XMPPInboxFieldOrderValue = @"asc";

NSString *const XMPPInboxErrorDomain = @"XMPPInboxErrorDomain";

@interface XMPPInbox()

@property (nonatomic, strong, nullable) NSString *requestQueryIdentifier;
@property (nonatomic, strong, nullable) XMPPIDTracker *xmppIDTracker;
@property (nonatomic, strong, nullable) NSMutableArray<XMPPMessage *> *reseavedResults;
@property (nonatomic, strong, nullable) NSMutableDictionary *unreadMessagesCount;
@property (nonatomic, strong, nullable) NSMutableDictionary *unreadMessageIdentifier;
@property (nonatomic, strong, nullable) NSDateFormatter *dateFormatter;

@end

@implementation XMPPInbox

@synthesize requestQueryIdentifier = _requestQueryIdentifier;
@synthesize xmppIDTracker = _xmppIDTracker;
@synthesize reseavedResults = _reseavedResults;
@synthesize unreadMessagesCount = _unreadMessagesCount;
@synthesize unreadMessageIdentifier = _unreadMessageIdentifier;
@synthesize dateFormatter = _dateFormatter;

#pragma mark - INIT METHODS & SUPERCLASS OVERRIDERS

- (instancetype)init {
    self = [self initWithDispatchQueue:nil];
    if (self) {
        self.dateFormatter = [NSDateFormatter new];
        [self.dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        [self.dateFormatter setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]];
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream {
    if ([super activate:aXmppStream]) {
        self.xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
        return YES;
    }
    return NO;
}

- (void)deactivate {
    dispatch_block_t block = ^{ @autoreleasepool {
        self.requestQueryIdentifier = nil;
        [self.xmppIDTracker removeAllIDs];
        self.xmppIDTracker = nil;
        self.reseavedResults = nil;
        self.unreadMessagesCount = nil;
        self.unreadMessageIdentifier = nil;
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_sync(moduleQueue, block);
    }
    [super deactivate];
}

#pragma mark - PUBLIC METHODS

- (void)discoverInboxMessages {
    dispatch_block_t block = ^{ @autoreleasepool {
        self.requestQueryIdentifier = nil;
        [self.xmppIDTracker removeAllIDs];
        self.reseavedResults = [NSMutableArray new];
        
        NSXMLElement *formTypeField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [formTypeField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldHidden];
        [formTypeField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldFormType];
        [formTypeField addChild:[NSXMLElement elementWithName:XMPPInboxValueQueryName stringValue:XMPPInboxXMLNS]];
        
        NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
        NSXMLElement *startField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [startField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [startField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldStart];
        [startField addChild:[NSXMLElement elementWithName:XMPPInboxValueQueryName stringValue:[self.dateFormatter stringFromDate:startDate]]];
    
        NSDate *endDate = [NSDate new];
        NSXMLElement *endField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [endField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [endField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldEnd];
        [endField addChild:[NSXMLElement elementWithName:XMPPInboxValueQueryName stringValue:[self.dateFormatter stringFromDate:endDate]]];
    
        NSXMLElement *orderField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [orderField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldListSingle];
        [orderField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldOrder];
        [orderField addChild:[NSXMLElement elementWithName:XMPPInboxValueQueryName stringValue:XMPPInboxFieldOrderValue]];
        
        NSXMLElement *onlyUnreadConversationsField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [onlyUnreadConversationsField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [onlyUnreadConversationsField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldHiddenRead];
        [onlyUnreadConversationsField addChild:[NSXMLElement elementWithName:XMPPInboxValueQueryName stringValue:XMPPInboxFieldFalseValue]];
        
        NSXMLElement *data = [NSXMLElement elementWithName:XMPPInboxDataQueryName xmlns:XMPPInboxDataXMLNS];
        [data addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxDataType];
        [data addChild:formTypeField];
        [data addChild:startField];
        [data addChild:endField];
        [data addChild:orderField];
        [data addChild:onlyUnreadConversationsField];
        
        NSXMLElement *query = [NSXMLElement elementWithName:XMPPInboxQueryName xmlns:XMPPInboxXMLNS];
        [query addAttributeWithName:XMPPInboxQueryIdentifierName stringValue:[self.xmppStream generateUUID]];
        [query addChild:data];
        
        NSString *queryIdentifier = [self.xmppStream generateUUID];
        XMPPIQ *iq = [XMPPIQ iqWithType:XMPPInboxIQType elementID:queryIdentifier child:query];
        self.requestQueryIdentifier = queryIdentifier;
        [self.xmppIDTracker addElement:iq target:self selector:@selector(handleDiscoverInboxMessagesQueryIQ:withInfo:) timeout:60];
        [self.xmppStream sendElement:iq];
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

- (NSInteger)unreadMessagesCountForChatJID:(XMPPJID *)chatJID {
    __block NSInteger result = 0;
    dispatch_block_t block = ^{ @autoreleasepool {
        result = [[self.unreadMessagesCount objectForKey:[chatJID bare]] integerValue];
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_sync(moduleQueue, block);
    }
    return result;
}

- (NSInteger)totalUnreadMessagesCount {
    __block NSInteger result = 0;
    dispatch_block_t block = ^{ @autoreleasepool {
        for (NSNumber *value in self.unreadMessagesCount.allValues) {
            result += [value integerValue];
        }
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_sync(moduleQueue, block);
    }
    return result;
}

- (NSString *)unreadMessageIdentifierFromWhichCountingStartsForChatJID:(XMPPJID *)chatJID {
    __block NSString *result = nil;
    dispatch_block_t block = ^{ @autoreleasepool {
        result = [self.unreadMessageIdentifier objectForKey:[chatJID bare]];
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_sync(moduleQueue, block);
    }
    return result;
}

#pragma mark - PRIVATE METHODS

- (void)handleDiscoverInboxMessagesQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info {
    dispatch_block_t block = ^{ @autoreleasepool {
        NSMutableArray *messages = [NSMutableArray new];
        NSMutableDictionary *unreadMessagesCount = [NSMutableDictionary new];
        NSMutableDictionary *unreadMessageIdentifier = [NSMutableDictionary new];
        if (self.reseavedResults && [self.reseavedResults count] > 0) {
            for (NSXMLElement *result in self.reseavedResults) {
                XMPPMessage *forwardedMessage = [result forwardedMessage];
                if (forwardedMessage) {
                    NSString *conversationBare = [forwardedMessage conversationBareWithStream:self.xmppStream];
                    if (conversationBare) {
                        NSInteger unreadCount = [[[result attributeForName:XMPPInboxUnreadName] stringValue] integerValue];
                        [unreadMessagesCount setObject:[NSNumber numberWithInteger:unreadCount] forKey:conversationBare];
                        
                        NSString *messageIdentifier = [[forwardedMessage attributeForName:XMPPInboxIdentifierName] stringValue];
                        if (messageIdentifier) {
                            [unreadMessageIdentifier setObject:messageIdentifier forKey:conversationBare];
                        } else {
                            [unreadMessageIdentifier removeObjectForKey:conversationBare];
                        }
                    }
                    [messages addObject:forwardedMessage];
                }
            }
        }
        
        self.requestQueryIdentifier = nil;
        self.reseavedResults = nil;
        self.unreadMessagesCount = unreadMessagesCount;
        self.unreadMessageIdentifier = unreadMessageIdentifier;
        
        NSXMLElement *errorElem = [iq elementForName:@"error"];
        if (errorElem) {
            NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
            NSInteger errorCode = [errorElem attributeIntegerValueForName:@"code" withDefaultValue:0];
            NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
            NSError *error = [NSError errorWithDomain:XMPPInboxErrorDomain code:errorCode userInfo:dict];
            [self.multicastDelegate xmppInbox:self didFailToDiscoverInboxMessages:error];
        } else {
            [self.multicastDelegate xmppInbox:self didDiscoverInboxMessages:messages];
        }
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

#pragma mark - XMPPStreamDelegate

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    dispatch_block_t block = ^{ @autoreleasepool {
        BOOL discoveryRequestInProgress = (self.requestQueryIdentifier != nil);
        NSString *conversationBare = [message conversationBareWithStream:sender];
        if (conversationBare && [message hasDisplayedChatMarker]) {
            if ([message hasDisplayedChatMarker]) {
                [self.unreadMessagesCount removeObjectForKey:conversationBare];
                [self.unreadMessageIdentifier removeObjectForKey:conversationBare];
                [self.multicastDelegate xmppInbox:self didUpdateInboxMessagesForChatWithJabberIdentifier:[XMPPJID jidWithString:conversationBare]];
            }
            
            if (discoveryRequestInProgress) {
                [self discoverInboxMessages];
            }
        }
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    dispatch_block_t block = ^{ @autoreleasepool {
        BOOL discoveryRequestInProgress = (self.requestQueryIdentifier != nil);
        NSXMLElement *result = [message elementForName:XMPPInboxResultQueryName xmlns:XMPPInboxXMLNS];
        NSString *resultIdentifier = [[result attributeForName:XMPPInboxQueryIdentifierName] stringValue];
        if (resultIdentifier && self.requestQueryIdentifier && [resultIdentifier isEqualToString:self.requestQueryIdentifier]) {
            [self.reseavedResults addObject:result];
        } else {
            XMPPMessage *messageToProcess = message;
            if ([message isMessageCarbon]) {
                messageToProcess = [message messageCarbonForwardedMessage];
            }
            
            NSString *streamBare = [[self.xmppStream myJID] bare];
            NSString *senderBare = [messageToProcess senderBareWithStream:self.xmppStream];
            NSString *conversationBare = [messageToProcess conversationBareWithStream:self.xmppStream];
            BOOL outgoing = [streamBare isEqualToString:senderBare];
            if (streamBare && senderBare && conversationBare && ([messageToProcess hasDisplayedChatMarker] || [messageToProcess isGroupChatMessageWithAffiliations] || [messageToProcess isGroupChatMessageWithBody] || [messageToProcess isChatMessageWithBody])) {
                if ([messageToProcess hasDisplayedChatMarker]) {
                    if (outgoing) {
                        [self.unreadMessagesCount removeObjectForKey:conversationBare];
                        [self.unreadMessageIdentifier removeObjectForKey:conversationBare];
                        [self.multicastDelegate xmppInbox:self didUpdateInboxMessagesForChatWithJabberIdentifier:[XMPPJID jidWithString:conversationBare]];
                    }
                } else {
                    NSString *messageIdentifier = [[messageToProcess attributeForName:XMPPInboxIdentifierName] stringValue];
                    NSInteger unreadMessagesCount = [[self.unreadMessagesCount objectForKey:conversationBare] integerValue];
                    if (!outgoing && messageIdentifier && unreadMessagesCount == 0) {
                        [self.unreadMessagesCount setObject:[NSNumber numberWithInteger:(unreadMessagesCount + 1)] forKey:conversationBare];
                        [self.unreadMessageIdentifier setObject:messageIdentifier forKey:conversationBare];
                        [self.multicastDelegate xmppInbox:self didUpdateInboxMessagesForChatWithJabberIdentifier:[XMPPJID jidWithString:conversationBare]];
                    }
                }
                
                if (discoveryRequestInProgress) {
                    [self discoverInboxMessages];
                }
            }
        }
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    __block NSString *requestQueryIdentifier = nil;
    dispatch_block_t block = ^{ @autoreleasepool {
        requestQueryIdentifier = self.requestQueryIdentifier;
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_sync(moduleQueue, block);
    }
    
    NSString *iqIdentifier = [iq elementID];
    if (iqIdentifier && requestQueryIdentifier && [iqIdentifier isEqualToString:requestQueryIdentifier]) {
        return [self.xmppIDTracker invokeForID:iqIdentifier withObject:iq];
    }
    return NO;
}

@end
