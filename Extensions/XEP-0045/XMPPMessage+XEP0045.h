#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage(XEP0045)

@property (nonatomic, readonly) BOOL isGroupChatMessage;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithBody;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithAffiliations;
@property (nonatomic, strong, readonly) NSString *groupChatMessageAffiliationsUser;
@property (nonatomic, strong, readonly) NSString *groupChatMessageAffiliationsType;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithSubject;

@end
