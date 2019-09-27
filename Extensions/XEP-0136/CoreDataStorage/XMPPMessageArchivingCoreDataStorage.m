#import "XMPPMessageArchivingCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPMessage+XEP_0085.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPMessage+XEP_0313.h"
#import "NSXMLElement+XEP_0297.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const XMPP_MESSAGE_IDENTIFIER_KEY = @"XMPP_MESSAGE_IDENTIFIER";
NSString *const XMPP_MESSAGE_FROM_KEY = @"XMPP_MESSAGE_FROM";
NSString *const XMPP_MESSAGE_TO_KEY = @"XMPP_MESSAGE_TO";
NSString *const XMPP_MESSAGE_DATE_KEY = @"XMPP_MESSAGE_DATE";
NSString *const XMPP_MESSAGE_IS_OUTGOING_KEY = @"XMPP_MESSAGE_IS_OUTGOING";

@interface XMPPMessageArchivingCoreDataStorage ()
{
	NSString *messageEntityName;
	NSString *contactEntityName;
    NSArray<NSString *> *relevantContentXPaths;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPMessageArchivingCoreDataStorage

static XMPPMessageArchivingCoreDataStorage *sharedInstance;

+ (instancetype)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPMessageArchivingCoreDataStorage alloc] initWithDatabaseFilename:nil storeOptions:nil];
	});
	
	return sharedInstance;
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 *
 * If your subclass needs to do anything for init, it can do so easily by overriding this method.
 * All public init methods will invoke this method at the end of their implementation.
 *
 * Important: If overriden you must invoke [super commonInit] at some point.
**/
- (void)commonInit
{
	[super commonInit];
	
	messageEntityName = @"XMPPMessageArchiving_Message_CoreDataObject";
	contactEntityName = @"XMPPMessageArchiving_Contact_CoreDataObject";
    
    relevantContentXPaths = @[@"./*[local-name()='body']"];
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 *
 * Override me, if needed, to provide customized behavior.
 * For example, you may want to perform cleanup of any non-persistent data before you start using the database.
 *
 * The default implementation does nothing.
**/
- (void)didCreateManagedObjectContext
{
	// If there are any "composing" messages in the database, delete them (as they are temporary).
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"composing == YES"];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	fetchRequest.entity = messageEntity;
	fetchRequest.predicate = predicate;
	fetchRequest.fetchBatchSize = saveThreshold;
	
	NSError *error = nil;
	NSArray *messages = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (messages == nil)
	{
		XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", [self class], THIS_METHOD, error);
		return;
	}
	
	NSUInteger count = 0;
	
	for (XMPPMessageArchiving_Message_CoreDataObject *message in messages)
	{
		[moc deleteObject:message];
		
		if (++count > saveThreshold)
		{
			if (![moc save:&error])
			{
				XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
				[moc rollback];
			}
		}
	}
	
	if (count > 0)
	{
		if (![moc save:&error])
		{
			XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
			[moc rollback];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)willInsertMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
	// Override hook
}

- (void)didUpdateMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
	// Override hook
}

- (void)willDeleteMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
	// Override hook
}

- (void)willInsertContact:(XMPPMessageArchiving_Contact_CoreDataObject *)contact
{
	// Override hook
}

- (void)didUpdateContact:(XMPPMessageArchiving_Contact_CoreDataObject *)contact
{
	// Override hook
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPMessageArchiving_Message_CoreDataObject *)archivedMessageWithResultIdentifier:(NSString *)resultIdentifier
                                                                        conversation:(NSString *)conversation
                                                                managedObjectContext:(NSManagedObjectContext *)moc
{
    XMPPMessageArchiving_Message_CoreDataObject *result = nil;
    
    NSEntityDescription *messageEntity = [self messageEntity:moc];
    

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ AND bareJidStr == %@", resultIdentifier, conversation];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = messageEntity;
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = @[sortDescriptor];
    fetchRequest.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (results == nil || error)
    {
        XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", THIS_FILE, THIS_METHOD, fetchRequest);
    }
    else
    {
        result = (XMPPMessageArchiving_Message_CoreDataObject *)[results lastObject];
    }
    
    return result;
}

- (XMPPMessageArchiving_Message_CoreDataObject *)archivedMessageFrom:(NSString *)from
														conversation:(NSString *)conversation
																body:(NSString *)body
																date:(NSDate *)date
													resultIdentifier:(NSString *)resultIdentifier
												managedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPMessageArchiving_Message_CoreDataObject *result = nil;
	
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	// Order matters:
	// 1. composing - most likely not many with it set to YES in database
	// 2. bareJidStr - splits database by number of conversations
	// 3. outgoing - splits database in half
	// 4. streamBareJidStr - might not limit database at all
	
	NSDate *minTimestamp = [date dateByAddingTimeInterval:-60];
	NSDate *maxTimestamp = [date dateByAddingTimeInterval: 60];
	NSPredicate *predicate;
	if (resultIdentifier) {
		predicate = [NSPredicate predicateWithFormat:@"identifier == %@ AND bareJidStr == %@ AND streamBareJidStr == %@", resultIdentifier, conversation, from];
	} else {
		predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@ AND streamBareJidStr == %@ AND body == %@ AND timestamp BETWEEN {%@, %@}", conversation, from, body, minTimestamp, maxTimestamp];
	}
	
	NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	fetchRequest.entity = messageEntity;
	fetchRequest.predicate = predicate;
	fetchRequest.sortDescriptors = @[sortDescriptor];
	fetchRequest.fetchLimit = 1;
	
	NSError *error = nil;
	NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (results == nil || error)
	{
		XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", THIS_FILE, THIS_METHOD, fetchRequest);
	}
	else
	{
		result = (XMPPMessageArchiving_Message_CoreDataObject *)[results lastObject];
	}
	
	return result;
}

- (BOOL)messageContainsRelevantContent:(XMPPMessage *)message
{
    for (NSString *XPath in self.relevantContentXPaths) {
        NSError *error;
        NSArray *nodes = [message nodesForXPath:XPath error:&error];
        if (!nodes) {
            XMPPLogError(@"%@: %@ - Error querying XPath (%@): %@", THIS_FILE, THIS_METHOD, XPath, error);
            continue;
        }
        
        for (NSXMLNode *node in nodes) {
            if (node.stringValue.length > 0) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)saveMessageToCoreData:(XMPPMessage *)message body:(NSString *)body outgoing:(BOOL)outgoing shouldDeleteComposingMessage:(BOOL)shouldDeleteComposingMessage isComposing:(BOOL)isComposing xmppStream:(XMPPStream *)xmppStream archiveIdentifier:(NSString *)archiveIdentifier previousArchiveIdentifier:(NSString *)previousArchiveIdentifier {
	NSManagedObjectContext *moc = [self managedObjectContext];
    NSDictionary *parsedMessageParameters = [self parsedMessageParametersFromMessage:message outgoing:outgoing xmppStream:xmppStream];
    
	NSString *resultIdentifier = [[message attributeForName:@"resultId"] stringValue];
	NSString *identifier = [parsedMessageParameters objectForKey:XMPP_MESSAGE_IDENTIFIER_KEY];
    NSDate *date = [parsedMessageParameters objectForKey:XMPP_MESSAGE_DATE_KEY];
    BOOL isOutgoing = [[parsedMessageParameters objectForKey:XMPP_MESSAGE_IS_OUTGOING_KEY] boolValue];
    NSString *from = [parsedMessageParameters objectForKey:XMPP_MESSAGE_FROM_KEY];
    NSString *to = [parsedMessageParameters objectForKey:XMPP_MESSAGE_TO_KEY];
    
    BOOL dataIsCorrect = (identifier && [identifier isKindOfClass:[NSString class]] && date && [date isKindOfClass:[NSDate class]] && from && [from isKindOfClass:[NSString class]] && to && [to isKindOfClass:[NSString class]]);
    if (!dataIsCorrect) {
        return;
    }
	
	// Fetch-n-Update OR Insert new message
	
	XMPPMessageArchiving_Message_CoreDataObject *archivedMessage = [self archivedMessageFrom:from conversation:to body:body date:date resultIdentifier:resultIdentifier managedObjectContext:moc];
	
	if (shouldDeleteComposingMessage)
	{
		if (archivedMessage)
		{
			[self willDeleteMessage:archivedMessage]; // Override hook
			[moc deleteObject:archivedMessage];
		}
		else
		{
			// Composing message has already been deleted (or never existed)
		}
	}
	else
	{
		XMPPLogVerbose(@"Previous archivedMessage: %@", archivedMessage);
		
		BOOL didCreateNewArchivedMessage = NO;
		if (archivedMessage == nil)
		{
			archivedMessage = (XMPPMessageArchiving_Message_CoreDataObject *)[[NSManagedObject alloc] initWithEntity:[self messageEntity:moc] insertIntoManagedObjectContext:nil];
			archivedMessage.body = body;
			archivedMessage.bareJid = [XMPPJID jidWithString:to];
			archivedMessage.streamBareJidStr = from;
			archivedMessage.timestamp = date;
			archivedMessage.thread = [[message elementForName:@"thread"] stringValue];
			archivedMessage.isOutgoing = isOutgoing;
			didCreateNewArchivedMessage = YES;
		}
		
		if (archivedMessage.archiveIdentifier == nil) {
			archivedMessage.archiveIdentifier = archiveIdentifier;
		}
		
		if (archivedMessage.previousArchiveIdentifier == nil) {
			archivedMessage.previousArchiveIdentifier = previousArchiveIdentifier;
		}
		
		archivedMessage.identifier = identifier;
		archivedMessage.message = message;
		archivedMessage.isComposing = isComposing;
		
		XMPPLogVerbose(@"New archivedMessage: %@", archivedMessage);
		
		if (didCreateNewArchivedMessage) // [archivedMessage isInserted] doesn't seem to work
		{
			XMPPLogVerbose(@"Inserting message...");
			
			[archivedMessage willInsertObject];       // Override hook
			[self willInsertMessage:archivedMessage]; // Override hook
			[moc insertObject:archivedMessage];
		}
		else
		{
			XMPPLogVerbose(@"Updating message...");
			
			[archivedMessage didUpdateObject];       // Override hook
			[self didUpdateMessage:archivedMessage]; // Override hook
		}
		
		// Create or update contact (if message with actual content)
		
		if (didCreateNewArchivedMessage && ([message isChatMessageWithBody] || [message isGroupChatMessageWithBody]))
		{
			BOOL didCreateNewContact = NO;
			
			NSArray<XMPPMessageArchiving_Contact_CoreDataObject *> *contacts = [self contactsWithBareJidStr:archivedMessage.bareJid.bare streamBareJidStr:nil managedObjectContext:moc];
			XMPPMessageArchiving_Contact_CoreDataObject *contact = [contacts lastObject];
			XMPPLogVerbose(@"Previous contact: %@", contact);
			
			if ([contacts count] > 1) {
				NSArray *contactsToDelete = [contacts subarrayWithRange:NSMakeRange(0, contacts.count - 1)];
				for (XMPPMessageArchiving_Contact_CoreDataObject *contactToDelete in contactsToDelete) {
					[self willDeleteMessage:contactToDelete];
					[moc deleteObject:contactToDelete];
				}
			}
			
			if (contact == nil)
			{
				contact = (XMPPMessageArchiving_Contact_CoreDataObject *)
				[[NSManagedObject alloc] initWithEntity:[self contactEntity:moc]
						 insertIntoManagedObjectContext:nil];
				
				didCreateNewContact = YES;
			}
			else if ([contact.mostRecentMessageTimestamp timeIntervalSince1970] > [archivedMessage.timestamp timeIntervalSince1970])
			{
				return;
			}
			
			contact.identifier = identifier;
			contact.streamBareJidStr = archivedMessage.streamBareJidStr;
			contact.bareJid = archivedMessage.bareJid;
			contact.mostRecentMessageTimestamp = archivedMessage.timestamp;
			contact.mostRecentMessageBody = archivedMessage.body;
			contact.mostRecentMessageOutgoing = @(isOutgoing);
			
			XMPPLogVerbose(@"New contact: %@", contact);
			
			if (didCreateNewContact) // [contact isInserted] doesn't seem to work
			{
				XMPPLogVerbose(@"Inserting contact...");
				
				[contact willInsertObject];       // Override hook
				[self willInsertContact:contact]; // Override hook
				[moc insertObject:contact];
			}
			else
			{
				XMPPLogVerbose(@"Updating contact...");
				
				[contact didUpdateObject];       // Override hook
				[self didUpdateContact:contact]; // Override hook
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)fetchMessagesInChatWithJID:(XMPPJID *)jid fetchLimit:(NSInteger)fetchLimit fetchOffset:(NSInteger)fetchOffset xmppStream:(XMPPStream *)xmppStream completion:(void (^)(NSArray<XMPPMessageModel *> *))completion {
    dispatch_block_t block = ^{
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *messageEntity = [self messageEntity:moc];
        
        NSFetchRequest *objectIDsFetchRequest = [[NSFetchRequest alloc] init];
        objectIDsFetchRequest.entity = messageEntity;
        objectIDsFetchRequest.predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", jid.bare];
        objectIDsFetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
        objectIDsFetchRequest.resultType = NSManagedObjectIDResultType;
        
        NSError *error = nil;
        NSArray *objectIDsResults = [moc executeFetchRequest:objectIDsFetchRequest error:&error];
        NSArray<NSManagedObjectID *> *objectIDs;
        if ([objectIDsResults count] > fetchOffset) {
            if ([objectIDsResults count] > fetchOffset + fetchLimit) {
                objectIDs = [objectIDsResults subarrayWithRange:NSMakeRange(fetchOffset, fetchLimit)];
            } else {
                objectIDs = [objectIDsResults subarrayWithRange:NSMakeRange(fetchOffset, ([objectIDsResults count] - fetchOffset))];
            }
        }
        
        NSMutableArray<XMPPMessageModel *> *messages = [NSMutableArray new];
        if (objectIDs && [objectIDs count] > 0) {
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            fetchRequest.entity = messageEntity;
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(self IN %@)", objectIDs];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
            
            NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
            if (results && [results count] > 0) {
                for (XMPPMessageArchiving_Message_CoreDataObject *result in results) {
                    if ([result body] && [result streamBareJidStr] && [result bareJidStr]) {
                        BOOL outgoing = ([result.bareJidStr isEqualToString:[[xmppStream myJID] bare]]);
                        XMPPMessageModel *message = [[XMPPMessageModel alloc] initWithIdentifier:result.identifier sender:result.streamBareJidStr recipient:result.bareJidStr text:result.body date:result.timestamp archiveIdentifier:result.archiveIdentifier previousArchiveIdentifier:result.previousArchiveIdentifier outgoing:outgoing];
                        [messages addObject:message];
                    }
                }
            }
        }
        completion(messages);
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
}

- (NSDictionary *)parsedMessageParametersFromMessage:(XMPPMessage *)message outgoing:(BOOL)outgoing xmppStream:(XMPPStream *)xmppStream {
	NSString *resultIdentifier = [[message attributeForName:@"resultId"] stringValue];
	NSString *identifier = (resultIdentifier != nil ? resultIdentifier : [xmppStream generateUUID]);
	NSDate *delayedDeliveryDate = [message delayedDeliveryDate];
    NSDate *date = (delayedDeliveryDate != nil ? delayedDeliveryDate : [NSDate new]);
    NSString *from;
    NSString *to;
    if ([message isGroupChatMessage]) {
        if ([[message from] resource]) {
            from = [[message from] resource];
            to = [[message from] bare];
        } else {
            from = [[xmppStream myJID] bare];
            to = [[message to] bare];
        }
    } else {
        if ([message from]) {
            from = (outgoing ? [[xmppStream myJID] bare] : [[message from] bare]);
            to = (outgoing ? [[message to] bare] : [[message from] bare]);
        } else {
            from = [[xmppStream myJID] bare];
            to = [[message to] bare];
        }
    }
    
    BOOL isOutgoing = (from != nil && [from isEqualToString:[[xmppStream myJID] bare]]);
    
    NSMutableDictionary *parsedParameters = [NSMutableDictionary new];
	[parsedParameters setObject:identifier forKey:XMPP_MESSAGE_IDENTIFIER_KEY];
    [parsedParameters setObject:date forKey:XMPP_MESSAGE_DATE_KEY];
    [parsedParameters setObject:[NSNumber numberWithBool:isOutgoing] forKey:XMPP_MESSAGE_IS_OUTGOING_KEY];
    if (from) {
        [parsedParameters setObject:from forKey:XMPP_MESSAGE_FROM_KEY];
    }
    if (to) {
        [parsedParameters setObject:to forKey:XMPP_MESSAGE_TO_KEY];
    }
	return parsedParameters;
}

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactForMessage:(XMPPMessageArchiving_Message_CoreDataObject *)msg
{
	// Potential override hook
	
	return [self contactWithBareJidStr:msg.bareJidStr
					  streamBareJidStr:msg.streamBareJidStr
				  managedObjectContext:msg.managedObjectContext];
}

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactWithJid:(XMPPJID *)contactJid
													  streamJid:(XMPPJID *)streamJid
										   managedObjectContext:(NSManagedObjectContext *)moc
{
	return [self contactWithBareJidStr:[contactJid bare]
					  streamBareJidStr:[streamJid bare]
				  managedObjectContext:moc];
}

- (NSArray<XMPPMessageArchiving_Contact_CoreDataObject *> *)contactsWithBareJidStr:(NSString *)contactBareJidStr
																  streamBareJidStr:(NSString *)streamBareJidStr
															  managedObjectContext:(NSManagedObjectContext *)moc
{
	NSEntityDescription *entity = [self contactEntity:moc];
	
	NSPredicate *predicate;
	if (streamBareJidStr)
	{
		predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@ AND streamBareJidStr == %@",
					 contactBareJidStr, streamBareJidStr];
	}
	else
	{
		predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", contactBareJidStr];
	}
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (results == nil)
	{
		XMPPLogError(@"%@: %@ - Fetch request error: %@", THIS_FILE, THIS_METHOD, error);
		return nil;
	}
	else
	{
		return results;
	}
}

- (void)clear
{
	dispatch_block_t block = ^{ @autoreleasepool {
		NSString *docsPath = [self persistentStoreDirectory];
		[[NSFileManager defaultManager] removeItemAtPath:docsPath error:nil];
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
}


- (NSString *)messageEntityName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = self->messageEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setMessageEntityName:(NSString *)entityName
{
	dispatch_block_t block = ^{
		self->messageEntityName = entityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (NSString *)contactEntityName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = self->contactEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setContactEntityName:(NSString *)entityName
{
	dispatch_block_t block = ^{
		self->contactEntityName = entityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc
{
	// This is a public method, and may be invoked on any queue.
	// So be sure to go through the public accessor for the entity name.
	
	return [NSEntityDescription entityForName:[self messageEntityName] inManagedObjectContext:moc];
}

- (NSEntityDescription *)contactEntity:(NSManagedObjectContext *)moc
{
	// This is a public method, and may be invoked on any queue.
	// So be sure to go through the public accessor for the entity name.
	
	return [NSEntityDescription entityForName:[self contactEntityName] inManagedObjectContext:moc];
}

- (NSArray<NSString *> *)relevantContentXPaths
{
	__block NSArray *result;

	dispatch_block_t block = ^{
		result = self->relevantContentXPaths;
	};

	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);

	return result;
}

- (void)setRelevantContentXPaths:(NSArray<NSString *> *)relevantContentXPathsToSet
{
	NSArray *newValue = [relevantContentXPathsToSet copy];
	
	dispatch_block_t block = ^{
		self->relevantContentXPaths = newValue;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Storage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)configureWithParent:(XMPPMessageArchiving *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
}

- (void)archiveMessage:(XMPPMessage *)message outgoing:(BOOL)outgoing xmppStream:(XMPPStream *)xmppStream
{
	// Message should either have a body, or be a composing notification
	
	if ([message isErrorMessage]) {
		return;
	}
	
	NSString *body = [[message elementForName:@"body"] stringValue];
	BOOL isComposing = NO;
	BOOL shouldDeleteComposingMessage = NO;
	
	if (![self messageContainsRelevantContent:message])
	{
		// Message doesn't have any content relevant for the module's user.
		// Check to see if it has a chat state (composing, paused, etc).
		
		isComposing = [message hasComposingChatState];
		if (!isComposing)
		{
			if ([message hasChatState])
			{
				// Message has non-composing chat state.
				// So if there is a current composing message in the database,
				// then we need to delete it.
				shouldDeleteComposingMessage = YES;
			}
			else
			{
				// Message has no body and no chat state.
				// Nothing to do with it.
				return;
			}
		}
	}
	
	[self scheduleBlock:^{
		[self saveMessageToCoreData:message body:body outgoing:outgoing shouldDeleteComposingMessage:shouldDeleteComposingMessage isComposing:isComposing xmppStream:xmppStream archiveIdentifier:nil previousArchiveIdentifier:nil];
	}];
}

- (void)archiveMAMMessages:(NSArray<XMPPMessage *> *)messages chatJID:(XMPPJID *)chatJID xmppStream:(XMPPStream *)xmppStream beforeMessageIdentifier:(NSString *)messageIdentifier {
	[self scheduleBlock:^{
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSString *archiveIdentifier = [xmppStream generateUUID];
        XMPPMessageArchiving_Message_CoreDataObject *beforeMessage = [self archivedMessageWithResultIdentifier:messageIdentifier conversation:chatJID.bare managedObjectContext:moc];
        NSString *previousArchiveIdentifier;
        if (beforeMessage && [beforeMessage archiveIdentifier]) {
            previousArchiveIdentifier = [beforeMessage archiveIdentifier];
        } else {
            previousArchiveIdentifier = archiveIdentifier;
        }
        
		for (XMPPMessage *message in messages) {
			NSXMLElement *resultElement = [message mamResult];
			XMPPMessage *internalMessage = [resultElement forwardedMessage];
			if (resultElement && internalMessage) {
				XMPPMessage *newMessage = [XMPPMessage messageFromElement:internalMessage];
				NSXMLElement *delayElement = [[resultElement elementForName:@"forwarded"] elementForName: @"delay"];
				if (delayElement) {
					[newMessage addChild:[delayElement copy]];
				}
				
				NSString *resultIdentifier = [resultElement attributeStringValueForName:@"id"];
				if (resultIdentifier) {
					[newMessage addAttributeWithName:@"resultId" stringValue:resultIdentifier];
				}
				
				if (newMessage && ![newMessage isErrorMessage]) {
					NSString *body = [[newMessage elementForName:@"body"] stringValue];
					if ([newMessage isGroupChatMessageWithBody]) {
						BOOL outgoing = ([[[newMessage from] resource] isEqualToString:[[xmppStream myJID] bare]]);
						[self saveMessageToCoreData:newMessage body:body outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:archiveIdentifier previousArchiveIdentifier:previousArchiveIdentifier];
					} else if ([newMessage isChatMessageWithBody]) {
						BOOL outgoing = ([[[newMessage from] bare] isEqualToString:[[xmppStream myJID] bare]]);
						[self saveMessageToCoreData:newMessage body:body outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:archiveIdentifier previousArchiveIdentifier:previousArchiveIdentifier];
					}
				}
			}
		}
	}];
}

- (void)deleteMessagesForJabberIdentifierBare:(NSString *)jabberIdentifierBare
{
	[self scheduleBlock:^{
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *messageEntity = [self messageEntity:moc];
		NSFetchRequest *messageFetchRequest = [[NSFetchRequest alloc] init];
		messageFetchRequest.entity = messageEntity;
		messageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", jabberIdentifierBare];
		
		NSBatchDeleteRequest *messageDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:messageFetchRequest];
		[moc executeRequest:messageDeleteRequest error:nil];
		
		NSEntityDescription *contactEntity = [self contactEntity:moc];
		NSFetchRequest *contactFetchRequest = [[NSFetchRequest alloc] init];
		contactFetchRequest.entity = contactEntity;
		contactFetchRequest.predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", jabberIdentifierBare];
		
		NSBatchDeleteRequest *contactDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:contactFetchRequest];
		[moc executeRequest:contactDeleteRequest error:nil];
	}];
}

@end
