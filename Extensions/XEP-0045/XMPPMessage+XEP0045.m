#import "XMPPMessage+XEP0045.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"];
}

- (BOOL)isGroupChatMessageWithBody
{
	if ([self isGroupChatMessage])
	{
		NSString *body = [[self elementForName:@"body"] stringValue];
		
		return ([body length] > 0);
	}
	
	return NO;
}

- (BOOL)isGroupChatMessageWithAffiliations
{
    if ([self isGroupChatMessage])
    {
        NSXMLElement *affiliationsElement = [self elementForName:@"x" xmlns:@"urn:xmpp:muclight:0#affiliations"];
        NSXMLElement *userElement = [affiliationsElement elementForName:@"user"];
        NSXMLElement *affiliationElement = [userElement attributeForName:@"affiliation"];
        
        NSString *user = [userElement stringValue];
        NSString *affiliation = [affiliationElement stringValue];
        
        return ([user length] > 0 && [affiliation length] > 0);
    }
    
    return NO;
}

- (NSString *)groupChatMessageAffiliationsUser
{
    NSXMLElement *affiliationsElement = [self elementForName:@"x" xmlns:@"urn:xmpp:muclight:0#affiliations"];
    NSXMLElement *userElement = [affiliationsElement elementForName:@"user"];
    
    NSString *user = [userElement stringValue];
    return user;
}

- (NSString *)groupChatMessageAffiliationsType
{
    NSXMLElement *affiliationsElement = [self elementForName:@"x" xmlns:@"urn:xmpp:muclight:0#affiliations"];
    NSXMLElement *userElement = [affiliationsElement elementForName:@"user"];
    NSXMLElement *affiliationElement = [userElement attributeForName:@"affiliation"];
    
    NSString *affiliation = [affiliationElement stringValue];
    return affiliation;
}

- (BOOL)isGroupChatMessageWithSubject
{
    if ([self isGroupChatMessage])
	{
        NSString *subject = [[self elementForName:@"subject"] stringValue];

		return ([subject length] > 0);
    }

    return NO;
}

@end
