

#import <Foundation/Foundation.h>

@interface SipAccount : NSObject

@property(nonatomic,retain) NSString* SipServer;
@property(nonatomic,retain) NSString* OutboundProxy;
@property(nonatomic,retain) NSString* SipUserId;
@property(nonatomic,retain) NSString* AuthenticateId;
@property(nonatomic,retain) NSString* AuthenticatePassword;

@end
