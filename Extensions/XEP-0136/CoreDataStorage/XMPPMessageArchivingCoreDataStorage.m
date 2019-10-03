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

NSString *const XMPP_MESSAGE_ARCHIVE_IDENTIFIER_KEY = @"XMPP_MESSAGE_ARCHIVE_IDENTIFIER";
NSString *const XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER_KEY = @"XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER";

NSString *const XMPP_MESSAGE_IDENTIFIER_KEY = @"XMPP_MESSAGE_IDENTIFIER";
NSString *const XMPP_MESSAGE_ORIGINAL_IDENTIFIER_KEY = @"XMPP_MESSAGE_ORIGINAL_IDENTIFIER";
NSString *const XMPP_MESSAGE_FROM_KEY = @"XMPP_MESSAGE_FROM";
NSString *const XMPP_MESSAGE_TO_KEY = @"XMPP_MESSAGE_TO";
NSString *const XMPP_MESSAGE_DATE_KEY = @"XMPP_MESSAGE_DATE";
NSString *const XMPP_MESSAGE_IS_OUTGOING_KEY = @"XMPP_MESSAGE_IS_OUTGOING";
NSString *const XMPP_MESSAGE_IS_SYSTEM_KEY = @"XMPP_MESSAGE_IS_SYSTEM";

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

- (XMPPMessageArchiving_Message_CoreDataObject *)archivedMessageInConversation:(NSString *)conversation
													 messageOriginalIdentifier:(NSString *)messageOriginalIdentifier
														  managedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPMessageArchiving_Message_CoreDataObject *result = nil;
	
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"originalIdentifier == %@ AND bareJidStr == %@", messageOriginalIdentifier, conversation];
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

- (XMPPMessageArchiving_Message_CoreDataObject *)archivedMessageInConversation:(NSString *)conversation
															 messageIdentifier:(NSString *)messageIdentifier
														  managedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPMessageArchiving_Message_CoreDataObject *result = nil;
	
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ AND bareJidStr == %@", messageIdentifier, conversation];
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

- (NSDictionary *)saveMessageToCoreData:(XMPPMessage *)message body:(NSString *)body outgoing:(BOOL)outgoing shouldDeleteComposingMessage:(BOOL)shouldDeleteComposingMessage isComposing:(BOOL)isComposing xmppStream:(XMPPStream *)xmppStream archiveIdentifier:(NSString *)archiveIdentifier previousArchiveIdentifier:(NSString *)previousArchiveIdentifier messageIndex:(NSUInteger)messageIndex {
	NSManagedObjectContext *moc = [self managedObjectContext];
    NSDictionary *parsedMessageParameters = [self parsedMessageParametersFromMessage:message outgoing:outgoing xmppStream:xmppStream];
    
    NSMutableDictionary *archivesIdentifiers = [NSMutableDictionary new];
    if (archiveIdentifier) {
        [archivesIdentifiers setObject:archiveIdentifier forKey:XMPP_MESSAGE_ARCHIVE_IDENTIFIER_KEY];
    }
    if (previousArchiveIdentifier) {
        [archivesIdentifiers setObject:previousArchiveIdentifier forKey:XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER_KEY];
    }
    
	NSString *identifier = [parsedMessageParameters objectForKey:XMPP_MESSAGE_IDENTIFIER_KEY];
	NSString *originalIdentifier = [parsedMessageParameters objectForKey:XMPP_MESSAGE_ORIGINAL_IDENTIFIER_KEY];
    NSDate *date = [parsedMessageParameters objectForKey:XMPP_MESSAGE_DATE_KEY];
    BOOL isOutgoing = [[parsedMessageParameters objectForKey:XMPP_MESSAGE_IS_OUTGOING_KEY] boolValue];
    BOOL isSystem = [[parsedMessageParameters objectForKey:XMPP_MESSAGE_IS_SYSTEM_KEY] boolValue];
    NSString *from = [parsedMessageParameters objectForKey:XMPP_MESSAGE_FROM_KEY];
    NSString *to = [parsedMessageParameters objectForKey:XMPP_MESSAGE_TO_KEY];
    
    BOOL dataIsCorrect = (from && [from isKindOfClass:[NSString class]] && to && [to isKindOfClass:[NSString class]]);
    if (!dataIsCorrect) {
        return archivesIdentifiers;
    }
	
	XMPPMessageArchiving_Message_CoreDataObject *archivedMessage = [self archivedMessageInConversation:to messageIdentifier:identifier managedObjectContext:moc];
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
			archivedMessage.thread = [[message elementForName:@"thread"] stringValue];
			archivedMessage.isOutgoing = isOutgoing;
            archivedMessage.isSystem = isSystem;
			didCreateNewArchivedMessage = YES;
        }
        
        NSDate *newArchiveDate = (date != nil ? date : (archivedMessage.timestamp != nil ? archivedMessage.timestamp : [NSDate new]));
        BOOL didChangeDateOfArchivedMessage = (newArchiveDate != archivedMessage.timestamp);
        if (didChangeDateOfArchivedMessage) {
            archivedMessage.timestamp = newArchiveDate;
        }
        
        if (archiveIdentifier && !previousArchiveIdentifier && messageIndex == 0) {
            [archivesIdentifiers setObject:archiveIdentifier forKey:XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER_KEY];
        }
		
		if (!archivedMessage.archiveIdentifier) {
			archivedMessage.archiveIdentifier = archiveIdentifier;
		}
		
		if (!archivedMessage.previousArchiveIdentifier && archivedMessage.archiveIdentifier != previousArchiveIdentifier) {
            archivedMessage.previousArchiveIdentifier = previousArchiveIdentifier;
		}
		
        archivedMessage.identifier = (identifier != nil ? identifier : archivedMessage.identifier);
		archivedMessage.originalIdentifier = (originalIdentifier != nil ? originalIdentifier : archivedMessage.originalIdentifier);
		archivedMessage.message = message;
		archivedMessage.isComposing = isComposing;
        
        if (archivedMessage.archiveIdentifier) {
            [archivesIdentifiers setObject:archivedMessage.archiveIdentifier forKey:XMPP_MESSAGE_ARCHIVE_IDENTIFIER_KEY];
        }
        if (archivedMessage.previousArchiveIdentifier) {
            [archivesIdentifiers setObject:archivedMessage.previousArchiveIdentifier forKey:XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER_KEY];
        }
		
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
		
		if ((didCreateNewArchivedMessage || didChangeDateOfArchivedMessage) && ([message isChatMessageWithBody] || [message isGroupChatMessageWithBody] || [message isGroupChatMessageWithAffiliations]))
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
				return archivesIdentifiers;
			}
			
			contact.identifier = archivedMessage.identifier;
			contact.streamBareJidStr = archivedMessage.streamBareJidStr;
			contact.bareJid = archivedMessage.bareJid;
			contact.mostRecentMessageTimestamp = archivedMessage.timestamp;
			contact.mostRecentMessageBody = archivedMessage.body;
			contact.mostRecentMessageOutgoing = @(isOutgoing);
			contact.mostRecentMessageSystem = @(isSystem);
			
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
    return archivesIdentifiers;
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
                    if ([result identifier] && [result body] && [result streamBareJidStr] && [result bareJidStr]) {
						XMPPMessageModel *message = [[XMPPMessageModel alloc] initWithIdentifier:result.identifier originalIdentifier:result.originalIdentifier sender:result.streamBareJidStr recipient:result.bareJidStr text:result.body date:result.timestamp archiveIdentifier:result.archiveIdentifier previousArchiveIdentifier:result.previousArchiveIdentifier outgoing:result.isOutgoing system:result.isSystem];
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
	NSString *identifier = [[message attributeForName:@"id"] stringValue];
	NSString *originalIdentifier = [[message attributeForName:@"resultId"] stringValue];
	if (!originalIdentifier) {
		originalIdentifier = [[[message elementForName:@"stanza-id" xmlns:@"urn:xmpp:sid:0"] attributeForName:@"id"] stringValue];
	}
	
	NSDate *delayedDeliveryDate = [message delayedDeliveryDate];
    NSDate *date = delayedDeliveryDate;
    
    NSString *from;
    NSString *to;
    BOOL isSystem = NO;
    if ([message isGroupChatMessageWithAffiliations]) {
        from = [message groupChatMessageAffiliationsUser];
        to = [[message from] bare];
        isSystem = YES;
    } else if ([message isGroupChatMessage]) {
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
    [parsedParameters setObject:[NSNumber numberWithBool:isOutgoing] forKey:XMPP_MESSAGE_IS_OUTGOING_KEY];
    [parsedParameters setObject:[NSNumber numberWithBool:isSystem] forKey:XMPP_MESSAGE_IS_SYSTEM_KEY];
    
	if (identifier) {
       [parsedParameters setObject:identifier forKey:XMPP_MESSAGE_IDENTIFIER_KEY];
    }
	if (originalIdentifier) {
       [parsedParameters setObject:originalIdentifier forKey:XMPP_MESSAGE_ORIGINAL_IDENTIFIER_KEY];
    }
    if (date) {
        [parsedParameters setObject:date forKey:XMPP_MESSAGE_DATE_KEY];
    }
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
	
	return [[self contactsWithBareJidStr:msg.bareJidStr
						streamBareJidStr:msg.streamBareJidStr
					managedObjectContext:msg.managedObjectContext] firstObject];
}

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactWithJid:(XMPPJID *)contactJid
													  streamJid:(XMPPJID *)streamJid
										   managedObjectContext:(NSManagedObjectContext *)moc
{
	return [[self contactsWithBareJidStr:[contactJid bare]
						streamBareJidStr:[streamJid bare]
					managedObjectContext:moc] firstObject];
}

- (BOOL)isMessageExists:(XMPPMessage *)message chatJID:(XMPPJID *)chatJID {
	__block BOOL isMessageExists = NO;
	dispatch_block_t block = ^{ @autoreleasepool {
		NSString *identifier = [[message attributeForName:@"id"] stringValue];
        NSManagedObjectContext *moc = [self managedObjectContext];
		XMPPMessageArchiving_Message_CoreDataObject *archivedMessage = [self archivedMessageInConversation:chatJID.bare messageIdentifier:identifier managedObjectContext:moc];
		isMessageExists = (archivedMessage != nil);
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return isMessageExists;
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
	
	if ([message isErrorMessage] || [message isGroupChatMessageWithAffiliations]) {
		return;
	}
	
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
		NSDictionary *archivesIdentifiers = [self saveMessageToCoreData:message body:message.body outgoing:outgoing shouldDeleteComposingMessage:shouldDeleteComposingMessage isComposing:isComposing xmppStream:xmppStream archiveIdentifier:nil previousArchiveIdentifier:nil messageIndex:0];
	}];
}

- (void)archiveMAMMessages:(NSArray<XMPPMessage *> *)messages chatJID:(XMPPJID *)chatJID xmppStream:(XMPPStream *)xmppStream beforeMessageOriginalIdentifier:(NSString *)messageOriginalIdentifier {
	[self scheduleBlock:^{
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSString *archiveIdentifier = [xmppStream generateUUID];
        NSString *previousArchiveIdentifier;
        if (messageIdentifier) {
            XMPPMessageArchiving_Message_CoreDataObject *beforeMessage = [self archivedMessageInConversation:chatJID.bare messageOriginalIdentifier:messageOriginalIdentifier managedObjectContext:moc];
            previousArchiveIdentifier = [beforeMessage archiveIdentifier];
        }
        
        NSUInteger messageIndex = 0;
		for (XMPPMessage *message in [messages reverseObjectEnumerator] ) {
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
                    NSDictionary *archivesIdentifiers;
                    if ([newMessage isGroupChatMessage]) {
                        if ([newMessage isGroupChatMessageWithBody]) {
                            BOOL outgoing = ([[[newMessage from] resource] isEqualToString:[[xmppStream myJID] bare]]);
                            archivesIdentifiers = [self saveMessageToCoreData:newMessage body:newMessage.body outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:archiveIdentifier previousArchiveIdentifier:previousArchiveIdentifier messageIndex:messageIndex];
                        } else if ([newMessage isGroupChatMessageWithAffiliations]) {
							BOOL outgoing = ([[newMessage groupChatMessageAffiliationsUser] isEqualToString:[[xmppStream myJID] bare]]);
                            archivesIdentifiers = [self saveMessageToCoreData:newMessage body:newMessage.groupChatMessageAffiliationsType outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:archiveIdentifier previousArchiveIdentifier:previousArchiveIdentifier messageIndex:messageIndex];
                        }
                    } else if ([newMessage isChatMessageWithBody]) {
						BOOL outgoing = ([[[newMessage from] bare] isEqualToString:[[xmppStream myJID] bare]]);
						archivesIdentifiers = [self saveMessageToCoreData:newMessage body:newMessage.body outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:archiveIdentifier previousArchiveIdentifier:previousArchiveIdentifier messageIndex:messageIndex];
                    }
                    
                    if (archivesIdentifiers) {
                        archiveIdentifier = [archivesIdentifiers objectForKey:XMPP_MESSAGE_ARCHIVE_IDENTIFIER_KEY];
                        previousArchiveIdentifier = [archivesIdentifiers objectForKey:XMPP_MESSAGE_PREVIOUS_ARCHIVE_IDENTIFIER_KEY];
                        messageIndex += 1;
                    }
				}
			}
		}
	}];
}
- (void)archiveAffiliationsMessageWithText:(NSString *)text chatJID:(XMPPJID *)chatJID senderJID:(XMPPJID *)senderJID outgoing:(BOOL)outgoing xmppStream:(XMPPStream *)xmppStream completion:(void (^)(XMPPMessage *))completion {
    [self scheduleBlock:^{
        XMPPElement *user = [XMPPElement elementWithName:@"user"];
        [user addAttributeWithName:@"affiliation" stringValue:text];
        [user setStringValue:[senderJID bare]];
        
        XMPPElement *x = [[XMPPElement alloc] initWithName:@"x" xmlns:@"urn:xmpp:muclight:0#affiliations"];
        [x addChild:user];
        
        XMPPMessage *message = [XMPPMessage messageWithType:@"groupchat"];
        [message addAttributeWithName:@"from" stringValue:[chatJID bare]];
        [message addChild:x];
        
        NSDictionary *archivesIdentifiers = [self saveMessageToCoreData:message body:message.groupChatMessageAffiliationsType outgoing:outgoing shouldDeleteComposingMessage:NO isComposing:NO xmppStream:xmppStream archiveIdentifier:nil previousArchiveIdentifier:nil messageIndex:0];
        completion(message);
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
