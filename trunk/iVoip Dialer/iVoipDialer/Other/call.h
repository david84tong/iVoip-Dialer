
#ifndef __iVoipDialer_CALL_H__
#define __iVoipDialer_CALL_H__

#include <pjsua-lib/pjsua.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SipAccount.h"
#import "Helper.h"

#import "constants.h"


#define VOLUME_MULT 8.0f

typedef struct app_config_t
{
  pj_pool_t             *pool;

  pjsua_config           cfg;
  pjsua_logging_config   log_cfg;
  pjsua_media_config     media_cfg;
  
  pjsua_transport_config udp_cfg;
  pjsua_transport_config rtp_cfg;
  pj_bool_t		    ringback_on;
  pj_bool_t		    ring_on;
  
  int           ringback_slot;
  int           ringback_cnt;
  pjmedia_port *ringback_port;
#if !RING_FILE
  int           ring_slot;
  int           ring_cnt;
  pjmedia_port *ring_port;
#else
  int               ring_cnt;
  SystemSoundID     ring_id;
  CFRunLoopTimerRef ring_timer;
#endif
} app_config_t;

PJ_BEGIN_DECL

pj_status_t sip_startup      (app_config_t *app_config);
pj_status_t sip_cleanup      (app_config_t *app_config);

pj_status_t sip_connect      (pj_pool_t *pool, pjsua_acc_id *acc_id);
pj_status_t sip_disconnect   (pjsua_acc_id *acc_id);

pj_status_t sip_dial_with_uri(pjsua_acc_id acc_id, const char *uri, 
                              pjsua_call_id *call_id);
pj_status_t sip_dial         (pjsua_acc_id acc_id, const char *number, 
                              pjsua_call_id *call_id);
pj_status_t sip_answer        (pjsua_call_id *call_id);
pj_status_t sip_hangup        (pjsua_call_id *call_id);

#if SETTINGS

pj_status_t sip_add_account(NSDictionary *account, pjsua_acc_id *acc_id);

#endif

PJ_END_DECL

#endif
