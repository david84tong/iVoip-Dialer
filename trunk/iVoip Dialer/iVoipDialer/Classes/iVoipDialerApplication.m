
#import "iVoipDialerApplication.h"
#import "Reachability.h"
#include <unistd.h>
#if defined(CYDIA) && (CYDIA == 1)
#import <CFNetwork/CFNetwork.h>
#include <sys/stat.h>
#endif


@implementation iVoipDialerApplication

@synthesize window;
@synthesize navController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window.rootViewController = navController;
    _sip_acc_id = PJSUA_INVALID_ID;
    [window makeKeyAndVisible];
	return YES;
}

- (void)hangup
{
    if(_sip_acc_id != PJSUA_INVALID_ID)
    {
        sip_hangup(&_sip_acc_id);
    }
}

-(void) dialup:(NSString *)phoneNumber
{
    pjsua_call_id callID;
    pj_status_t status;
    if ([self sipConnect])
    {
        NSRange range = [phoneNumber rangeOfString:@"@"];
        if (range.location != NSNotFound)
        {
            status = sip_dial_with_uri(_sip_acc_id, [[NSString stringWithFormat:@"sip:%@", phoneNumber] UTF8String], &callID);
        }
        else
        {
            status = sip_dial(_sip_acc_id, [phoneNumber UTF8String], &callID);
        }
        if (status != PJ_SUCCESS)
        {
            const pj_str_t *str = pjsip_get_status_text(status);
            NSString *msg = [[NSString alloc]
                             initWithBytes:str->ptr 
                             length:str->slen 
                             encoding:[NSString defaultCStringEncoding]];
            NSLog(@"Call failed %@", msg);
        }
    }
}

- (app_config_t *)pjsipConfig
{
    return &_app_config;
}


- (BOOL)sipStartup
{
    if (_app_config.pool)
        return YES;
    if (sip_startup(&_app_config) != PJ_SUCCESS)
    {
        return NO;
    }
    return YES;
}

- (BOOL)sipConnect
{
    pj_status_t status;
    
    if (![self sipStartup])
        return FALSE;
    if (_sip_acc_id == PJSUA_INVALID_ID)
    {
        if ((status = sip_connect(_app_config.pool, &_sip_acc_id)) != PJ_SUCCESS)
        {
            return FALSE;
        }
    }
    
    return TRUE;
}

/* */
- (BOOL)sipDisconnect
{
    if ((_sip_acc_id != PJSUA_INVALID_ID) &&
        (sip_disconnect(&_sip_acc_id) != PJ_SUCCESS))
    {
        return FALSE;
    }
    
    _sip_acc_id = PJSUA_INVALID_ID;
    return TRUE;
}

- (void)dealloc {
	[navController release];
	[window release];
	[super dealloc];
}


@end
