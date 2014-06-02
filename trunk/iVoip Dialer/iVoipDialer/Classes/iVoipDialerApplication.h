

#import <UIKit/UIKit.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#if defined(CYDIA) && (CYDIA == 1)
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#endif
#import "Reachability.h"
#import "PhoneCallDelegate.h"
#include "call.h"

//#define MWI 1
#define REACHABILITY_2_0 1

@class iVoipDialerApplication;

@interface iVoipDialerApplication : NSObject   <UIActionSheetDelegate,
	UIApplicationDelegate,
  PhoneCallDelegate>
{
    UIWindow *window;
    UINavigationController *navController;
    //pjsip
    app_config_t _app_config;
    pjsua_acc_id  _sip_acc_id;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navController;

//Implement for Sip Lib
- (app_config_t *)pjsipConfig;
- (BOOL)sipStartup;
- (BOOL)sipConnect;
- (BOOL)sipDisconnect;
- (void)hangup;
@end
