#import "XMPPInbox.h"
#import "XMPPFramework.h"
#import "XMPPIDTracker.h"

NSString *const XMPPInboxIQType = @"set";
NSString *const XMPPInboxDataQueryName = @"x";
NSString *const XMPPInboxFieldQueryName = @"field";
NSString *const XMPPInboxQueryName = @"inbox";
NSString *const XMPPInboxValueName = @"value";

NSString *const XMPPInboxTypeName = @"type";
NSString *const XMPPInboxFieldVariableName = @"var";
NSString *const XMPPInboxQueryIdentifierName = @"queryid";

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

@interface XMPPInbox () {
    XMPPIDTracker *xmppIDTracker;
    NSDateFormatter *dateFormatter;
}
@end

@implementation XMPPInbox

#pragma mark - INIT METHODS & SUPERCLASS OVERRIDERS

- (instancetype)init {
    self = [self initWithDispatchQueue:nil];
    if (self) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        [dateFormatter setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]];
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream {
    if ([super activate:aXmppStream]) {
        xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
        return YES;
    }
    return NO;
}

- (void)deactivate {
    dispatch_block_t block = ^{ @autoreleasepool {
        [self->xmppIDTracker removeAllIDs];
        self->xmppIDTracker = nil;
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
//    <iq type="set" id="10bca">
//      <inbox xmlns=”erlang-solutions.com:xmpp:inbox:0” queryid="b6">
//        <x xmlns='jabber:x:data' type='form'>
//          <field type='hidden' var='FORM_TYPE'><value>erlang-solutions.com:xmpp:inbox:0</value></field>
//          <field type='text-single' var='start'><value>2018-07-10T12:00:00Z</value></field>
//          <field type='text-single' var='end'><value>2018-07-11T12:00:00Z</value></field>
//          <field type='list-single' var='order'><value>asc</value></field>
//          <field type='text-single' var='hidden_read'><value>true</value></field>
//        </x>
//      </inbox>
//    </iq>
    
    dispatch_block_t block = ^{ @autoreleasepool {
        NSXMLElement *formTypeField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [formTypeField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldHidden];
        [formTypeField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldFormType];
        [formTypeField addChild:[NSXMLElement elementWithName:XMPPInboxValueName stringValue:XMPPInboxXMLNS]];
        
        NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
        NSXMLElement *startField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [startField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [startField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldStart];
        [startField addChild:[NSXMLElement elementWithName:XMPPInboxValueName stringValue:[self->dateFormatter stringFromDate:startDate]]];
    
        NSDate *endDate = [NSDate new];
        NSXMLElement *endField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [endField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [endField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldEnd];
        [endField addChild:[NSXMLElement elementWithName:XMPPInboxValueName stringValue:[self->dateFormatter stringFromDate:endDate]]];
    
        NSXMLElement *orderField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [orderField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldListSingle];
        [orderField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldOrder];
        [orderField addChild:[NSXMLElement elementWithName:XMPPInboxValueName stringValue:XMPPInboxFieldOrderValue]];
        
        NSXMLElement *onlyUnreadConversationsField = [NSXMLElement elementWithName:XMPPInboxFieldQueryName];
        [onlyUnreadConversationsField addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxFieldTextSingle];
        [onlyUnreadConversationsField addAttributeWithName:XMPPInboxFieldVariableName stringValue:XMPPInboxFieldHiddenRead];
        [onlyUnreadConversationsField addChild:[NSXMLElement elementWithName:XMPPInboxValueName stringValue:XMPPInboxFieldFalseValue]];
        
        NSXMLElement *data = [NSXMLElement elementWithName:XMPPInboxDataQueryName xmlns:XMPPInboxDataXMLNS];
        [data addAttributeWithName:XMPPInboxTypeName stringValue:XMPPInboxDataType];
        [data addChild:formTypeField];
        [data addChild:startField];
        [data addChild:endField];
        [data addChild:orderField];
        [data addChild:onlyUnreadConversationsField];
        
        NSXMLElement *query = [NSXMLElement elementWithName:XMPPInboxQueryName xmlns:XMPPInboxXMLNS];
        [query addAttributeWithName:XMPPInboxQueryIdentifierName stringValue:[self->xmppStream generateUUID]];
        [query addChild:data];
        
        //    <iq type='get' id='c94a88ddf4957128eafd08e233f4b964'>
        //      <query xmlns='erlang-solutions.com:xmpp:inbox:0'/>
        //    </iq>
        
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get" elementID:[self->xmppStream generateUUID]];
        [iq addChild:[NSXMLElement elementWithName:@"query" xmlns:@"erlang-solutions.com:xmpp:inbox:0"]];
        
        
//        XMPPIQ *iq = [XMPPIQ iqWithType:XMPPInboxIQType elementID:[self->xmppStream generateUUID] child:query];
        NSLog(@"\n\nXMPP INBOX SEND IQ: %@\n\n", iq);
        [self->xmppIDTracker addElement:iq target:self selector:@selector(handleDiscoverInboxMessagesQueryIQ:withInfo:) timeout:60];
        [self->xmppStream sendElement:iq];
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

#pragma mark - PRIVATE METHODS

- (void)handleDiscoverInboxMessagesQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info {
    dispatch_block_t block = ^{ @autoreleasepool {
        NSLog(@"\n\nXMPP INBOX RECEIVE IQ: %@\nINFO: %@\n\n", iq, [info element]);
        
        NSXMLElement *errorElem = [iq elementForName:@"error"];
        if (errorElem) {
            NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
            NSInteger errorCode = [errorElem attributeIntegerValueForName:@"code" withDefaultValue:0];
            NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
            NSError *error = [NSError errorWithDomain:XMPPInboxErrorDomain code:errorCode userInfo:dict];
            [self->multicastDelegate xmppInbox:self didFailToDiscoverInboxMessages:error];
            return;
        } else {
            NSLog(@"");
        }
        
//        NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCLightDiscoItemsNamespace];
//        NSArray *items = [query elementsForName:@"item"];
//        [self->multicastDelegate xmppInbox:self didReceiveChatMessage:[XMPPMessage message]];
    }};
    
    if (dispatch_get_specific(moduleQueueTag)) {
        block();
    } else {
        dispatch_async(moduleQueue, block);
    }
}

#pragma mark - XMPPStreamDelegate

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    NSLog(@"XMPP INBOX message: %@", message);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    NSLog(@"XMPP INBOX iq: %@", iq);
    
    NSString *type = [iq type];
    if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]) {
        return [xmppIDTracker invokeForID:[iq elementID] withObject:iq];
    }
    return NO;
}

@end
