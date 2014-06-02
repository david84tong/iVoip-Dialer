

#import "Helper.h"

@implementation Helper

+(void)setSipAccount:(SipAccount*)sipAccount
{
    NSUserDefaults* setting = [NSUserDefaults standardUserDefaults];
    NSData *dataStore = [NSKeyedArchiver archivedDataWithRootObject:sipAccount];
    [setting setObject:dataStore forKey:@"sipAccount"];
    [setting synchronize];
}

+(SipAccount*)getSipAccount
{
    NSUserDefaults *settings =[NSUserDefaults standardUserDefaults];
    NSData *dataStore = [settings objectForKey:@"sipAccount"];
    if( dataStore )
    {
        return (SipAccount *)[NSKeyedUnarchiver unarchiveObjectWithData: dataStore];
    }
    return nil;
}

@end
