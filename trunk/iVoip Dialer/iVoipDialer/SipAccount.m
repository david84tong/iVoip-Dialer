

#import "SipAccount.h"

@implementation SipAccount
@synthesize SipServer;
@synthesize OutboundProxy;
@synthesize SipUserId;
@synthesize AuthenticateId;
@synthesize AuthenticatePassword;

-(void)encodeWithCoder:(NSCoder *)encoder
{
    //Encode the properties of the object
    [encoder encodeObject:self.SipServer forKey:@"SipServer"];
    [encoder encodeObject:self.OutboundProxy forKey:@"OutboundProxy"];
    [encoder encodeObject:self.SipUserId forKey:@"SipUserId"];
    [encoder encodeObject:self.AuthenticateId forKey:@"AuthenticateId"];
    [encoder encodeObject:self.AuthenticatePassword forKey:@"AuthenticatePassword"];
}

-(id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if ( self != nil )
    {
        //decode the properties
        self.SipServer = [decoder decodeObjectForKey:@"SipServer"];
        self.OutboundProxy = [decoder decodeObjectForKey:@"OutboundProxy"];
        self.SipUserId = [decoder decodeObjectForKey:@"SipUserId"];
        self.AuthenticateId = [decoder decodeObjectForKey:@"AuthenticateId"];
        self.AuthenticatePassword = [decoder decodeObjectForKey:@"AuthenticatePassword"];
    }
    return self;
}

-(void)dealloc
{
    [SipServer release];
    [OutboundProxy release];
    [SipUserId release];
    [AuthenticateId release];
    [AuthenticatePassword release];
    [super dealloc];
}

@end
