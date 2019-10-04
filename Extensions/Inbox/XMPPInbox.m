#import "XMPPInbox.h"
#import "XMPPFramework.h"
#import "XMPPIDTracker.h"

NSString *const XMPPMUCLightDiscoItemsNamespace = @"http://jabber.org/protocol/disco#items";
NSString *const XMPPRoomLightAffiliations = @"urn:xmpp:muclight:0#affiliations";
NSString *const XMPPMUCLightErrorDomain = @"XMPPMUCErrorDomain";
NSString *const XMPPMUCLightBlocking = @"urn:xmpp:muclight:0#blocking";

@interface XMPPInbox () {
    XMPPIDTracker *xmppIDTracker;
}
@end

@implementation XMPPMessageArchiving

#pragma mark - INIT METHODS & SUPERCLASS OVERRIDERS

- (instancetype)init {
    return [self initWithDispatchQueue:nil];
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
    dispatch_block_t block = ^{ @autoreleasepool {
        NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCLightDiscoItemsNamespace];
        XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:[XMPPJID jidWithString:serviceName] elementID:[self->xmppStream generateUUID] child:query];
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
        NSXMLElement *errorElem = [iq elementForName:@"error"];
        NSString *serviceName = [iq attributeStringValueForName:@"from" withDefaultValue:@""];
        
        if (errorElem) {
            NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
            NSInteger errorCode = [errorElem attributeIntegerValueForName:@"code" withDefaultValue:0];
            NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
            NSError *error = [NSError errorWithDomain:XMPPMUCLightErrorDomain code:errorCode userInfo:dict];
            [self->multicastDelegate xmppMUCLight:self failedToDiscoverRoomsForServiceNamed:serviceName withError:error];
            return;
        }
        
        NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCLightDiscoItemsNamespace];
        NSArray *items = [query elementsForName:@"item"];
        [self->multicastDelegate xmppInbox:self didReceiveChatMessage:[XMPPMessage message]];
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
