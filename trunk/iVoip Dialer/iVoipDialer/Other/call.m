

#import "NSNotificationAdditions.h"
#import "iVoipDialerApplication.h"

#include <pjsua-lib/pjsua.h>

#include "call.h"
#include "ring.h"
#include "dtmf.h"

#define MWI 1


#define THIS_FILE "call.m"

NSString *kiVoipDialerCallState         = @"CallState";
NSString *kiVoipDialerRegState          = @"RegState";
NSString *kiVoipDialerMwiInfo           = @"MWIInfo";


static void postCallStateNotification(pjsua_call_id call_id, const pjsua_call_info *ci)
{
  NSString *remoteInfo = @"", *remoteContact = @"";
  NSAutoreleasePool *autoreleasePool = [[ NSAutoreleasePool alloc ] init];
  
  if (ci->remote_info.slen)
    remoteInfo = [NSString stringWithUTF8String:ci->remote_info.ptr];
  if (ci->remote_contact.slen)
    remoteContact = [NSString stringWithUTF8String:ci->remote_contact.ptr];
  // FIXME: create an Object, InCall for example ?
  NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt: call_id], @"CallID",
                            [NSNumber numberWithInt: ci->role], @"Role",
                            [NSNumber numberWithInt: ci->acc_id], @"AccountID",
                            remoteInfo, @"RemoteInfo",
                            remoteContact, @"RemoteContact",
                            [NSNumber numberWithInt: ci->state], @"State",
                            [NSNumber numberWithInt:ci->last_status], @"LastStatus",
                            [NSNumber numberWithInt:ci->media_status], @"MediaStatus",
                            [NSNumber numberWithInt:ci->conf_slot], @"ConfSlot",
                            [NSNumber  numberWithLong:ci->connect_duration.sec], @"ConnectDuration",
                            [NSNumber  numberWithLong:ci->total_duration.sec], @"TotalDuration",
                            nil];
  
  [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:kiVoipDialerCallState
                                                                      object:nil 
                                                                    userInfo:userinfo];
  [autoreleasePool release ];
}


/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
  pjsua_call_info ci;
  iVoipDialerApplication *app = (iVoipDialerApplication *)[[UIApplication sharedApplication] delegate];
  pjsua_call_get_info(call_id, &ci);
  
  PJ_LOG(1,(THIS_FILE, "Call %d state=%.*s", call_id,
    (int)ci.state_text.slen, ci.state_text.ptr));

  if (ci.state == PJSIP_INV_STATE_DISCONNECTED) // Session is terminated.
  {
    ///* FIXME: Stop all ringback for this call */
    sip_ring_stop([app pjsipConfig]);
    sip_call_deinit_tonegen(call_id);
  } 
  else if (ci.state == PJSIP_INV_STATE_EARLY) 
  {
    int code;
    pj_str_t reason;
    pjsip_msg *msg;
    
    /* This can only occur because of TX or RX message */
    pj_assert(e->type == PJSIP_EVENT_TSX_STATE);
    
    msg = (e->body.tsx_state.type == PJSIP_EVENT_RX_MSG ?
           e->body.tsx_state.src.rdata->msg_info.msg :
           e->body.tsx_state.src.tdata->msg);

    code = msg->line.status.code;
    reason = msg->line.status.reason;
    
    /* Start ringback for 180 for UAC unless there's SDP in 180 */
    if (ci.role == PJSIP_ROLE_UAC && code == 180 && 
        msg->body == NULL && 
        ci.media_status == PJSUA_CALL_MEDIA_NONE) 
    {
      // FIXME: start ringback
      sip_ringback_start([app pjsipConfig]);
    }
	}
    if (ci.state != PJSIP_INV_STATE_NULL)
    {
        postCallStateNotification(call_id, &ci);
    }
}

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
           pjsip_rx_data *rdata)
{
  pjsua_call_info ci;
  iVoipDialerApplication *app = (iVoipDialerApplication *)[[UIApplication sharedApplication] delegate];

  PJ_UNUSED_ARG(acc_id);
  PJ_UNUSED_ARG(rdata);

  pjsua_call_get_info(call_id, &ci);

  PJ_LOG(1,(THIS_FILE, "Incoming call from %.*s!!",
     (int)ci.remote_info.slen,
     ci.remote_info.ptr));
  
  /* FIXME: Start ringback */
  sip_ring_start([app pjsipConfig]);
  
  
  /* Automatically answer incoming calls with 180/RINGING */
  pjsua_call_answer(call_id, 180, NULL, NULL);
  
  postCallStateNotification(call_id, &ci);
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info ci;
    iVoipDialerApplication *app = (iVoipDialerApplication *)[[UIApplication sharedApplication] delegate];

    pjsua_call_get_info(call_id, &ci);
    sip_ring_stop([app pjsipConfig]); 
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE ||
        ci.media_status == PJSUA_CALL_MEDIA_REMOTE_HOLD)
    {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

/*
 * Handler registration status has changed.
 */
static void on_reg_state(pjsua_acc_id acc_id)
{
    pj_status_t status;
    pjsua_acc_info info;
    NSString *accUri = @"", *statusText = @"";
    
    status = pjsua_acc_get_info(acc_id, &info);
    if (status != PJ_SUCCESS)
        return;
    
    // Log already written.
    NSLog(@"Status changed acc %d %.*s (%d)", acc_id, (int)info.status_text.slen,
          info.status_text.ptr, info.status);
    
    NSAutoreleasePool *autoreleasePool = [[ NSAutoreleasePool alloc ] init];
    
    if (info.acc_uri.slen)
        accUri = [NSString stringWithUTF8String:info.acc_uri.ptr];
    
    if (info.status_text.slen)
        statusText = [NSString stringWithUTF8String:info.status_text.ptr];
    
    NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt: acc_id], @"AccountID",
                              [NSNumber numberWithBool:info.is_default], @"IsDefault",
                              accUri, @"AccountUri",
                              [NSNumber numberWithBool:info.has_registration], @"HasRegistration",
                              [NSNumber numberWithInt: info.expires], @"Expires",
                              [NSNumber numberWithInt: info.status], @"Status",
                              statusText, @"StatusText",
                              [NSNumber numberWithBool:info.online_status], @"OnlineStatus",
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:kiVoipDialerRegState
                                                                        object:nil
                                                                      userInfo:userinfo];
    
    [ autoreleasePool release ];
  
}


#if defined(MWI) && MWI==1
/*
 * MWI indication
 */
static void on_mwi_info(pjsua_acc_id acc_id, pjsua_mwi_info *mwi_info)
{
    pj_str_t body;
    NSString *bodyText;
    
    PJ_LOG(3,(THIS_FILE, "Received MWI for acc %d:", acc_id));
    
    if (mwi_info->rdata->msg_info.ctype) {
        const pjsip_ctype_hdr *ctype = mwi_info->rdata->msg_info.ctype;
        
        PJ_LOG(3,(THIS_FILE, " Content-Type: %.*s/%.*s",
                  (int)ctype->media.type.slen,
                  ctype->media.type.ptr,
                  (int)ctype->media.subtype.slen,
                  ctype->media.subtype.ptr));
    }
    
    if (!mwi_info->rdata->msg_info.msg->body) {
        PJ_LOG(3,(THIS_FILE, "  no message body"));
        return;
    }
    
    body.ptr = mwi_info->rdata->msg_info.msg->body->data;
    body.slen = mwi_info->rdata->msg_info.msg->body->len;
    
    PJ_LOG(3,(THIS_FILE, " Body:\n%.*s", (int)body.slen, body.ptr));
    
    if (body.slen == 0)
        return;
    
    NSAutoreleasePool *autoreleasePool = [[ NSAutoreleasePool alloc ] init];
    bodyText = [NSString stringWithUTF8String:body.ptr];
    
    NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt: acc_id], @"AccountID",
                              bodyText, @"Body",
                              nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:kiVoipDialerMwiInfo
                                                                        object:nil
                                                                      userInfo:userinfo];
    [autoreleasePool release];
}
#endif /* MWI */

 
    
/* */
pj_status_t sip_startup(app_config_t *app_config)
{
    pj_status_t status;
    long val;
    char tmp[80];
    pjsua_transport_id transport_id = -1;
    
    const char *srv;
    
    const char *ip_addr;
    
    NSArray * array;
    NSString *dns;
    /* Create pjsua first! */
    status = pjsua_create();
    if (status != PJ_SUCCESS)
        return status;
    
    /* Create pool for application */
    app_config->pool = pjsua_pool_create("pjsua", 1000, 1000);
    
    /* Initialize default config */
    pjsua_config_default(&(app_config->cfg));
    pj_ansi_snprintf(tmp, 80, "Siphon PjSip v%s/%s", pj_get_version(), PJ_OS_NAME);
    pj_strdup2_with_null(app_config->pool, &(app_config->cfg.user_agent), tmp);
    
    pjsua_logging_config_default(&(app_config->log_cfg));
    
    val = [[NSUserDefaults standardUserDefaults] integerForKey:
           @"logLevel"];
#ifdef RELEASE_VERSION
    app_config->log_cfg.msg_logging = PJ_FALSE;
    app_config->log_cfg.console_level = 0;
    app_config->log_cfg.level = 0;
#else
    app_config->log_cfg.msg_logging = (val!=0 ? PJ_TRUE : PJ_FALSE);
    app_config->log_cfg.console_level = val;
    app_config->log_cfg.level = val;
    if (val != 0)
    {
#if defined(CYDIA) && (CYDIA == 1)
        NSArray *filePaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *path = [NSString stringWithFormat:@"%@/Siphon", [filePaths objectAtIndex:0]];
#else
        NSArray *filePaths =	NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,
                                                                     NSUserDomainMask,
                                                                     YES);
		NSString *path = [filePaths objectAtIndex: 0];
#endif
        path = [path stringByAppendingString: @"/log.txt"];
        
        app_config->log_cfg.log_filename = pj_strdup3(app_config->pool,
                                                      [path UTF8String]);
    }
#endif
    
    pjsua_media_config_default(&(app_config->media_cfg));
    app_config->media_cfg.clock_rate = 16000;
    app_config->media_cfg.snd_clock_rate = 16000;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"enableEC"])
        app_config->media_cfg.ec_tail_len = 0;
    
    // Enable/Disable VAD/silence detector
    app_config->media_cfg.no_vad = [[NSUserDefaults standardUserDefaults]
                                    boolForKey:@"disableVad"];
    
    app_config->media_cfg.snd_auto_close_time = 0;
    app_config->media_cfg.enable_ice = [[NSUserDefaults standardUserDefaults]
                                        boolForKey:@"enableICE"];
    
    pjsua_transport_config_default(&(app_config->udp_cfg));
    val = [[NSUserDefaults standardUserDefaults] integerForKey: @"localPort"];
    if (val < 0 || val > 65535)
    {
        PJ_LOG(1,(THIS_FILE,
                  "Error: local-port argument value (expecting 0-65535"));
        //[app displayParameterError:
        //@"Invalid value for Local Port (expecting 1-65535)."];
        //Show error detail here
        
        status = PJ_EINVAL;
        goto error;
    }
    app_config->udp_cfg.port = val;
    
    pjsua_transport_config_default(&(app_config->rtp_cfg));
    app_config->rtp_cfg.port = [[NSUserDefaults standardUserDefaults]
                                integerForKey: @"rtpPort"];
    if (app_config->rtp_cfg.port == 0)
    {
        enum { START_PORT=4000 };
        unsigned range;
        
        range = (65535-START_PORT-PJSUA_MAX_CALLS*2);
        app_config->rtp_cfg.port = START_PORT +
        ((pj_rand() % range) & 0xFFFE);
    }
    
    if (app_config->rtp_cfg.port < 1 || app_config->rtp_cfg.port > 65535)
    {
        PJ_LOG(1,(THIS_FILE,
                  "Error: rtp-port argument value (expecting 1-65535)"));
        //[app displayParameterError:
        // @"Invalid value for RTP port (expecting 1-65535)."];
        //Show error detail here
        status = PJ_EINVAL;
        goto error;
    }
    
#if 1
    ip_addr = [[[NSUserDefaults standardUserDefaults] stringForKey:
                @"boundAddr"] UTF8String];
    if (ip_addr && strlen(ip_addr))
    {
        pj_strdup2_with_null(app_config->pool,
                             &(app_config->udp_cfg.bound_addr),
                             ip_addr);
        pj_strdup2_with_null(app_config->pool,
                             &(app_config->rtp_cfg.bound_addr),
                             ip_addr);
    }
    
    ip_addr = [[[NSUserDefaults standardUserDefaults] stringForKey:
                @"publicAddr"] UTF8String];
    if (ip_addr && strlen(ip_addr))
    {
        pj_strdup2_with_null(app_config->pool,
                             &(app_config->udp_cfg.public_addr),
                             ip_addr);
        pj_strdup2_with_null(app_config->pool,
                             &(app_config->rtp_cfg.public_addr),
                             ip_addr);
    }
#endif
    
    /* Initialize application callbacks */
    app_config->cfg.cb.on_call_state = &on_call_state;
    app_config->cfg.cb.on_call_media_state = &on_call_media_state;
    app_config->cfg.cb.on_incoming_call = &on_incoming_call;
    app_config->cfg.cb.on_reg_state = &on_reg_state;
#if defined(MWI) && MWI==1
    app_config->cfg.cb.on_mwi_info = &on_mwi_info;
    app_config->cfg.enable_unsolicited_mwi = PJ_TRUE;
#endif
    
    srv = [[[NSUserDefaults standardUserDefaults] stringForKey:
            @"stunServer"] UTF8String];
    if (srv && strlen(srv))
    {
        if (app_config->cfg.stun_srv_cnt==PJ_ARRAY_SIZE(app_config->cfg.stun_srv))
        {
            PJ_LOG(1,(THIS_FILE, "Error: too many STUN servers"));
            return PJ_ETOOMANY;
        }
        pj_strdup2_with_null(app_config->pool,
                             &(app_config->cfg.stun_srv[app_config->cfg.stun_srv_cnt++]),
                             srv);
    }
    SipAccount* sipAccount = [Helper getSipAccount];
    NSString* outBoundProxy = sipAccount.OutboundProxy;
    app_config->cfg.outbound_proxy[0] = pj_str((char*)[[NSString stringWithFormat:@"sip:%@",outBoundProxy] UTF8String]);
    app_config->cfg.outbound_proxy_cnt = 1;
    
    dns = [[NSUserDefaults standardUserDefaults] stringForKey: @"dnsServer"];
    array = [dns componentsSeparatedByString:@","];
    NSEnumerator *enumerator = [array objectEnumerator];
    NSString *anObject;
    while (anObject = [enumerator nextObject])
    {
        NSMutableString *mutableStr = [anObject mutableCopy];
        CFStringTrimWhitespace((CFMutableStringRef)mutableStr);
        srv = [mutableStr UTF8String];
        if (srv && strlen(srv))
        {
            if (app_config->cfg.nameserver_count==PJ_ARRAY_SIZE(app_config->cfg.nameserver))
            {
                PJ_LOG(1,(THIS_FILE, "Error: too many DNS servers"));
                [mutableStr release];
                break;
            }
            pj_strdup2_with_null(app_config->pool,
                                 &(app_config->cfg.nameserver[app_config->cfg.nameserver_count++]),
                                 srv);
        }
        [mutableStr release];
    }
    /* Initialize pjsua */
    status = pjsua_init(&app_config->cfg, &app_config->log_cfg,
                        &app_config->media_cfg);
    if (status != PJ_SUCCESS)
        goto error;
    
    /* Initialize Ring and Ringback */
    sip_ring_init(app_config);
    
    /* Add UDP transport. */
    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP,
                                    &app_config->udp_cfg, &transport_id);
    if (status != PJ_SUCCESS)
        goto error;

    /* Initialization is done, now start pjsua */
    status = pjsua_start();
    if (status != PJ_SUCCESS)
        goto error;
    
    return status;
error:
    sip_cleanup(app_config);
    return status;
}


/* */
pj_status_t sip_cleanup(app_config_t *app_config)
{
  pj_status_t status;

  /* Cleanup Ring and Ringback */
  sip_ring_deinit(app_config);
  
  if (app_config->pool) 
  {
    pj_pool_release(app_config->pool);
    app_config->pool = NULL;
  }

  /* Destroy pjsua */
  status = pjsua_destroy();
  
  pj_bzero(app_config, sizeof(app_config_t));
  
  return status;
  
}

/* */
pj_status_t sip_connect(pj_pool_t *pool, pjsua_acc_id *acc_id)
{
  pj_status_t status;
  pjsua_acc_config acc_cfg;
  const char *uname;
  const char *authname;
  const char *passwd;
  const char *server;
  //Get Sip Account from NSUserDefault
  SipAccount* sipAccount = [Helper getSipAccount];
  uname  = [sipAccount.SipUserId UTF8String];
  authname  = [sipAccount.AuthenticateId UTF8String];
  
  passwd = [sipAccount.AuthenticatePassword UTF8String];
  server = [sipAccount.SipServer UTF8String];
  pjsua_acc_config_default(&acc_cfg);
  // ID
  acc_cfg.id.ptr = (char*) pj_pool_alloc(/*app_config.*/pool, PJSIP_MAX_URL_SIZE);
  acc_cfg.id.slen = pj_ansi_snprintf(acc_cfg.id.ptr, PJSIP_MAX_URL_SIZE,
                                       "sip:%s@%s", uname, server);
  if ((status = pjsua_verify_sip_url(acc_cfg.id.ptr)) != 0) 
  {
    PJ_LOG(1,(THIS_FILE, "Error: invalid SIP URL '%s' in local id argument", 
      acc_cfg.id));
    //[app displayParameterError: @"Invalid value for username or server."];
      //Show error detail here
    return status;
  }
  
  // Registrar
  acc_cfg.reg_uri.ptr = (char*) pj_pool_alloc(/*app_config.*/pool, 
    PJSIP_MAX_URL_SIZE);
  acc_cfg.reg_uri.slen = pj_ansi_snprintf(acc_cfg.reg_uri.ptr, 
    PJSIP_MAX_URL_SIZE, "sip:%s", server);
  if ((status = pjsua_verify_sip_url(acc_cfg.reg_uri.ptr)) != 0) 
  {
    PJ_LOG(1,(THIS_FILE,  "Error: invalid SIP URL '%s' in registrar argument",
      acc_cfg.reg_uri));
    //Show error detail here
    return status;
  }

  acc_cfg.cred_count = 1;
  acc_cfg.cred_info[0].scheme = pj_str("Digest");
  acc_cfg.cred_info[0].realm = pj_str("*");
  if (authname && strlen(authname))
    acc_cfg.cred_info[0].username = pj_str((char *)authname);
  else
    acc_cfg.cred_info[0].username = pj_str((char *)uname);
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableMJ"])
    acc_cfg.cred_info[0].data_type = PJSIP_CRED_DATA_DIGEST;
  else
    acc_cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
  acc_cfg.cred_info[0].data = pj_str((char *)passwd);
  
  acc_cfg.publish_enabled = PJ_TRUE;
#if defined(MWI) && MWI==1
  acc_cfg.mwi_enabled = PJ_TRUE;
#endif

  acc_cfg.allow_contact_rewrite = [[NSUserDefaults standardUserDefaults] 
                                   boolForKey:@"enableNat"];
  if (acc_cfg.reg_timeout < 1 || acc_cfg.reg_timeout > 3600) 
  {
    PJ_LOG(1,(THIS_FILE, 
      "Error: invalid value for timeout (expecting 1-3600)"));
      //Show error detail here
    return PJ_EINVAL;
  }
  
  // Keep alive interval
    acc_cfg.ka_interval = 90;

  // proxies server
  NSString *proxies = [[NSUserDefaults standardUserDefaults] stringForKey: @"proxyServer"];
  NSArray *array = [proxies componentsSeparatedByString:@","];
  NSEnumerator *enumerator = [array objectEnumerator];
  NSString *anObject;
  while (anObject = [enumerator nextObject])
  {
    NSMutableString *mutableStr = [anObject mutableCopy];
    CFStringTrimWhitespace((CFMutableStringRef)mutableStr);
    const char *proxy = [mutableStr UTF8String];
    if (proxy && strlen(proxy))
    {
      if (acc_cfg.proxy_cnt==PJ_ARRAY_SIZE(acc_cfg.proxy)) 
      {
        PJ_LOG(1,(THIS_FILE, "Error: too many proxy servers"));
        [mutableStr release];
        break;
      }
      pj_str_t pj_proxy;
      pj_proxy.slen = strlen(proxy) + 8;
      pj_proxy.ptr = (char*) pj_pool_alloc(pool, pj_proxy.slen);
      pj_proxy.slen = pj_ansi_snprintf(pj_proxy.ptr, pj_proxy.slen, "sip:%s;lr", proxy);
      if ((status = pjsua_verify_sip_url(pj_proxy.ptr)) != 0) 
      {
        PJ_LOG(1,(THIS_FILE,  "Error: invalid SIP URL '%*.s' in proxy argument (%d)",
                  pj_proxy.slen, pj_proxy.ptr, status));
        [mutableStr release];
        //Show error detail here
        continue;
      }
      acc_cfg.proxy[acc_cfg.proxy_cnt++] = pj_proxy;
    }
    [mutableStr release];
  }

    status = pjsua_acc_add(&acc_cfg, PJ_TRUE, acc_id);
    if (status != PJ_SUCCESS)
    {
        pjsua_perror(THIS_FILE, "Error adding new account", status);
        //Show error detail here
    }
  return status;
}

/* */
pj_status_t sip_disconnect(pjsua_acc_id *acc_id)
{
  pj_status_t status = PJ_SUCCESS;
  
  if (pjsua_acc_is_valid(*acc_id))
  {
    status = pjsua_acc_del(*acc_id);
    if (status == PJ_SUCCESS)
      *acc_id = PJSUA_INVALID_ID;
  }
  
  return status;
}

/* */
pj_status_t sip_dial_with_uri(pjsua_acc_id acc_id, const char *uri, 
                     pjsua_call_id *call_id)
{

  pj_status_t status = PJ_SUCCESS;
  pj_str_t pj_uri;

  PJ_LOG(5,(THIS_FILE,  "Calling URI \"%s\".", uri));

  status = pjsua_verify_sip_url(uri);
  if (status != PJ_SUCCESS) 
  {
    PJ_LOG(1,(THIS_FILE,  "Invalid URL \"%s\".", uri));
    pjsua_perror(THIS_FILE, "Invalid URL", status);
    return status;
  }
  
  pj_uri = pj_str((char *)uri);
  status = pjsua_call_make_call(acc_id, &pj_uri, 0, NULL, NULL, call_id);
  if (status != PJ_SUCCESS)
  {
    pjsua_perror(THIS_FILE, "Error making call", status);
  }
  
  return status;
}

pj_status_t sip_dial(pjsua_acc_id acc_id, const char *number, 
  pjsua_call_id *call_id)
{
  char uri[256];
  const char *sip_domain;
  SipAccount* sipAccount = [Helper getSipAccount];
  sip_domain = [sipAccount.SipServer UTF8String];
  
  pj_ansi_snprintf(uri, 256, "sip:%s@%s", number, sip_domain);
  return sip_dial_with_uri(acc_id, uri, call_id);
}

/* */
pj_status_t sip_answer(pjsua_call_id *call_id)
{
  pj_status_t status;

  status = pjsua_call_answer(*call_id, 200, NULL, NULL);
  if (status != PJ_SUCCESS)
  {
    *call_id = PJSUA_INVALID_ID;
  }

  return status;
}

/* */
pj_status_t sip_hangup(pjsua_call_id *call_id)
{
  pj_status_t status = PJ_SUCCESS;
  
  //pjsua_call_hangup_all();
  /* TODO Hangup current calls */
  if (*call_id != PJSUA_INVALID_ID)
    status = pjsua_call_hangup(*call_id, 0, NULL, NULL);
  *call_id = PJSUA_INVALID_ID;
  
  return status;
}
