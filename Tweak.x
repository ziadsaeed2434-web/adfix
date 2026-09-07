#import <substrate.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <ifaddrs.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <AdSupport/ASIdentifierManager.h>
#import <NetworkExtension/NetworkExtension.h>

// ----------------------------------------------------------------------
// 1. Configuration & Constants
// ----------------------------------------------------------------------

static NSArray<NSString *> *vpnInterfaceNameSubstrings;
static NSArray<NSString *> *ipLookupHosts;
static NSArray<NSString *> *atlantaZipCodes;
static NSArray<NSDictionary *> *ispData;

// قائمة الأنماط للمفاتيح الإعلانية (نفس القائمة السابقة)
static NSSet<NSString *> *adKeySubstrings;

// كلمات تدل على أن المفتاح زمني
static NSArray<NSString *> *timeKeySubstrings;

// Keys for associated objects
static char kFakeTaskKey;
static char kFakeCompletionKey;

// نطاق IP السكني: 172.56.0.0/13
static uint32_t residentialBase = 0xAC380000;
static uint32_t residentialMask = 0xFFF80000;

// الهوية الوهمية الثابتة لهذه الجلسة
static NSString *fakeIP = nil;
static NSString *fakeZip = nil;
static double fakeLat = 0;
static double fakeLon = 0;
static NSString *fakeISPName = nil;
static NSString *fakeISPOrg = nil;
static NSString *fakeISPAS = nil;

// UUID ثابت لهذه الجلسة (لـ IDFA)
static NSUUID *sessionAdvertisingIdentifier = nil;

// ----------------------------------------------------------------------
// 2. Helpers
// ----------------------------------------------------------------------

static BOOL isIPResidential(NSString *ip) {
    NSArray *parts = [ip componentsSeparatedByString:@"."];
    if (parts.count != 4) return NO;
    uint32_t octets[4] = {0};
    for (int i = 0; i < 4; i++) octets[i] = [parts[i] intValue];
    uint32_t ipInt = (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    return ((ipInt & residentialMask) == (residentialBase & residentialMask));
}

static NSString *generateRandomIPString(void) {
    NSString *ip;
    do {
        uint32_t random = arc4random_uniform(0x00080000);
        uint32_t ipInt = residentialBase | random;
        uint8_t b1 = (ipInt >> 24) & 0xFF;
        uint8_t b2 = (ipInt >> 16) & 0xFF;
        uint8_t b3 = (ipInt >> 8) & 0xFF;
        uint8_t b4 = ipInt & 0xFF;
        ip = [NSString stringWithFormat:@"%d.%d.%d.%d", b1, b2, b3, b4];
    } while (!isIPResidential(ip) || [ip hasSuffix:@".0"] || [ip hasSuffix:@".255"]);
    return ip;
}

static void generateFakeIdentity(void) {
    fakeIP = generateRandomIPString();
    fakeZip = atlantaZipCodes[arc4random_uniform((uint32_t)atlantaZipCodes.count)];
    fakeLat = 33.65 + ((double)arc4random_uniform(3000) / 10000.0);
    fakeLon = -84.55 + ((double)arc4random_uniform(3000) / 10000.0);
    NSDictionary *isp = ispData[arc4random_uniform((uint32_t)ispData.count)];
    fakeISPName = isp[@"name"];
    fakeISPOrg = isp[@"org"];
    fakeISPAS = isp[@"as"];
}

static NSString *generateFakeIPResponse(void) {
    if (!fakeIP) generateFakeIdentity();
    NSString *json = [NSString stringWithFormat:
        @"{\"status\":\"success\","
        "\"country\":\"United States\","
        "\"countryCode\":\"US\","
        "\"region\":\"GA\","
        "\"regionName\":\"Georgia\","
        "\"city\":\"Atlanta\","
        "\"zip\":\"%@\","
        "\"lat\":%.4f,"
        "\"lon\":%.4f,"
        "\"timezone\":\"America/New_York\","
        "\"isp\":\"%@\","
        "\"org\":\"%@\","
        "\"as\":\"%@\","
        "\"query\":\"%@\","
        "\"proxy\":false,"
        "\"hosting\":false,"
        "\"vpn\":false,"
        "\"tor\":false,"
        "\"datacenter\":false}",
        fakeZip, fakeLat, fakeLon, fakeISPName, fakeISPOrg, fakeISPAS, fakeIP];
    return json;
}

// فحص إذا كان المفتاح إعلانيًا
static BOOL isAdKey(NSString *key) {
    for (NSString *sub in adKeySubstrings) {
        if ([key rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

// فحص إذا كان المفتاح زمنيًا (يحتوي على كلمات تدل على الوقت)
static BOOL isTimeKey(NSString *key) {
    for (NSString *sub in timeKeySubstrings) {
        if ([key rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

// توليد زمن عشوائي بين ساعة وساعتين مضت (بالميللي ثانية)
static long long randomTimeBetweenOneAndTwoHoursAgoMillis(void) {
    long long oneHourMillis = 3600000;
    long long twoHoursMillis = 7200000;
    long long randomMillis = oneHourMillis + arc4random_uniform((uint32_t)(twoHoursMillis - oneHourMillis + 1));
    long long currentMillis = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    return currentMillis - randomMillis;
}

// ----------------------------------------------------------------------
// 3. Original C Function Pointers
// ----------------------------------------------------------------------

static int (*original_getifaddrs)(struct ifaddrs **);
static CFStringRef (*original_SCNetworkInterfaceGetName)(SCNetworkInterfaceRef);
static CFStringRef (*original_SCNetworkInterfaceGetInterfaceType)(SCNetworkInterfaceRef);
static CFDictionaryRef (*original_SCDynamicStoreCopyProxies)(SCDynamicStoreRef);
static CFDictionaryRef (*original_CFNetworkCopySystemProxySettings)(void);
static Boolean (*original_SCNetworkReachabilityGetFlags)(SCNetworkReachabilityRef, SCNetworkReachabilityFlags *);

// ----------------------------------------------------------------------
// 4. Hooked C Functions
// ----------------------------------------------------------------------

static int hooked_getifaddrs(struct ifaddrs **ifap) {
    int result = original_getifaddrs(ifap);
    if (result == 0 && ifap != NULL && *ifap != NULL) {
        struct ifaddrs *current = *ifap;
        struct ifaddrs *previous = NULL;
        while (current != NULL) {
            NSString *name = [NSString stringWithUTF8String:current->ifa_name ?: ""];
            BOOL isVPN = NO;
            for (NSString *sub in vpnInterfaceNameSubstrings) {
                if ([name rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    isVPN = YES;
                    break;
                }
            }
            if (isVPN) {
                if (previous == NULL) {
                    *ifap = current->ifa_next;
                    current = current->ifa_next;
                } else {
                    previous->ifa_next = current->ifa_next;
                    current = current->ifa_next;
                }
            } else {
                previous = current;
                current = current->ifa_next;
            }
        }
    }
    return result;
}

static CFStringRef hooked_SCNetworkInterfaceGetName(SCNetworkInterfaceRef interface) {
    CFStringRef originalName = original_SCNetworkInterfaceGetName(interface);
    if (originalName == NULL) return NULL;
    NSString *name = (__bridge NSString *)originalName;
    BOOL isVPN = NO;
    for (NSString *sub in vpnInterfaceNameSubstrings) {
        if ([name rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
            isVPN = YES;
            break;
        }
    }
    if (isVPN) return CFSTR("en0");
    return originalName;
}

static CFStringRef hooked_SCNetworkInterfaceGetInterfaceType(SCNetworkInterfaceRef interface) {
    CFStringRef originalType = original_SCNetworkInterfaceGetInterfaceType(interface);
    if (originalType == NULL) return NULL;
    CFStringRef nameRef = original_SCNetworkInterfaceGetName(interface);
    if (nameRef == NULL) return originalType;
    NSString *name = (__bridge NSString *)nameRef;
    BOOL isVPN = NO;
    for (NSString *sub in vpnInterfaceNameSubstrings) {
        if ([name rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
            isVPN = YES;
            break;
        }
    }
    if (isVPN) return CFSTR("WiFi");
    return originalType;
}

static CFDictionaryRef hooked_SCDynamicStoreCopyProxies(SCDynamicStoreRef store) {
    static CFDictionaryRef emptyProxies = NULL;
    if (emptyProxies == NULL) {
        emptyProxies = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
    }
    CFRetain(emptyProxies);
    return emptyProxies;
}

static CFDictionaryRef hooked_CFNetworkCopySystemProxySettings(void) {
    static CFDictionaryRef emptyProxies = NULL;
    if (emptyProxies == NULL) {
        emptyProxies = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
    }
    CFRetain(emptyProxies);
    return emptyProxies;
}

static Boolean hooked_SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags) {
    Boolean result = original_SCNetworkReachabilityGetFlags(target, flags);
    if (result && flags) {
        *flags &= ~kSCNetworkReachabilityFlagsTransientConnection;
        *flags |= kSCNetworkReachabilityFlagsReachable;
    }
    return result;
}

// ----------------------------------------------------------------------
// 5. Hooks for NetworkExtension
// ----------------------------------------------------------------------

%hook NEVPNManager
- (BOOL)enabled { return NO; }
%end

%hook NEVPNConnection
- (NEVPNStatus)status { return NEVPNStatusDisconnected; }
%end

// ----------------------------------------------------------------------
// 6. NSURLSession Interception (فقط لفحوصات IP)
// ----------------------------------------------------------------------

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                           completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSString *host = request.URL.host.lowercaseString;
    BOOL shouldIntercept = NO;
    for (NSString *h in ipLookupHosts) {
        if ([host hasSuffix:h] || [host isEqualToString:h]) {
            shouldIntercept = YES;
            break;
        }
    }

    if (shouldIntercept) {
        // طلب فحص IP: نعترضه بالكامل
        NSURL *dummyURL = [NSURL URLWithString:@"http://127.0.0.1:1"];
        NSURLRequest *dummyRequest = [NSURLRequest requestWithURL:dummyURL];
        NSURLSessionDataTask *task = %orig(dummyRequest, ^(NSData *data, NSURLResponse *response, NSError *error) {});
        if (task) {
            objc_setAssociatedObject(task, &kFakeTaskKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(task, &kFakeCompletionKey, completionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        return task;
    } else {
        // لا نضيف ترويسات IP للحفاظ على طلبات الإعلانات سليمة
        return %orig;
    }
}

%end

// ----------------------------------------------------------------------
// 7. Hook resume on NSURLSessionDataTask
// ----------------------------------------------------------------------

%hook NSURLSessionDataTask

- (void)resume {
    NSNumber *isFake = objc_getAssociatedObject(self, &kFakeTaskKey);
    if (isFake && [isFake boolValue]) {
        void (^completion)(NSData *, NSURLResponse *, NSError *) = objc_getAssociatedObject(self, &kFakeCompletionKey);
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *json = generateFakeIPResponse();
                NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://127.0.0.1:1"]
                                                                          statusCode:200
                                                                         HTTPVersion:@"HTTP/1.1"
                                                                        headerFields:@{@"Content-Type": @"application/json"}];
                completion(data, response, nil);
            });
        }
        return;
    }
    %orig;
}

- (void)cancel {
    NSNumber *isFake = objc_getAssociatedObject(self, &kFakeTaskKey);
    if (isFake && [isFake boolValue]) {
        objc_setAssociatedObject(self, &kFakeTaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kFakeCompletionKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        %orig;
        return;
    }
    %orig;
}

%end

// ----------------------------------------------------------------------
// 8. إرجاع IDFA جديد لكل جلسة
// ----------------------------------------------------------------------

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return sessionAdvertisingIdentifier;
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// ----------------------------------------------------------------------
// 9. اعتراض NSUserDefaults لمفاتيح الوقت الإعلانية فقط
// ----------------------------------------------------------------------

%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        return @(randomTimeBetweenOneAndTwoHoursAgoMillis());
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        return (NSInteger)(randomTimeBetweenOneAndTwoHoursAgoMillis());
    }
    return %orig;
}

- (double)doubleForKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        // بعض الشبكات تستخدم الثواني كـ double
        long long millis = randomTimeBetweenOneAndTwoHoursAgoMillis();
        return (double)millis / 1000.0;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        return; // لا تحفظ الوقت الجديد
    }
    %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        return;
    }
    %orig;
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName {
    if (isAdKey(defaultName) && isTimeKey(defaultName)) {
        return;
    }
    %orig;
}

%end

// ----------------------------------------------------------------------
// 10. Constructor
// ----------------------------------------------------------------------

%ctor {
    vpnInterfaceNameSubstrings = @[@"tun", @"tap", @"ppp", @"ipsec", @"utun", @"pptp", @"l2tp", @"vpn"];
    ipLookupHosts = @[
        @"ip-api.com", @"ipinfo.io", @"ipwho.is", @"ipapi.co", @"ipgeolocation.io",
        @"ip2location.com", @"maxmind.com", @"ipqualityscore.com", @"getipintel.net",
        @"proxycheck.io", @"iphub.info", @"vpnapi.io", @"ipdata.co", @"ipstack.com",
        @"ipvigilante.com", @"freegeoip.app", @"extreme-ip-lookup.com", @"ipify.org",
        @"ipapi.com", @"ipregistry.co", @"ip.sb", @"ipwhois.app", @"ifconfig.co",
        @"ipapi.is", @"ip2location.io"
    ];

    atlantaZipCodes = @[
        @"30301", @"30303", @"30305", @"30308", @"30309", @"30310", @"30312", @"30313",
        @"30314", @"30315", @"30316", @"30317", @"30318", @"30319", @"30324", @"30326",
        @"30327", @"30328", @"30329", @"30331", @"30332", @"30334", @"30339", @"30342",
        @"30344", @"30346", @"30349", @"30350", @"30354", @"30363"
    ];

    ispData = @[
        @{@"name": @"Comcast Cable", @"org": @"Comcast Cable Communications, LLC", @"as": @"AS7922 Comcast Cable Communications, LLC"},
        @{@"name": @"AT&T Internet", @"org": @"AT&T Services, Inc.", @"as": @"AS7018 AT&T Services, Inc."},
        @{@"name": @"Spectrum", @"org": @"Charter Communications", @"as": @"AS20115 Charter Communications"},
        @{@"name": @"Verizon Fios", @"org": @"Verizon Business", @"as": @"AS701 Verizon Business"}
    ];

    // القائمة الكبيرة للأنماط الإعلانية
    adKeySubstrings = [NSSet setWithObjects:
        @"Capping", @"lastShown", @"lastVisit", @"sessionCount",
        @"SKANLastUpdatedTime", @"com.supersonic.events", @"vungle.connectivity.wait",
        @"com.inobi_defaultStore_f", @"com.inobi_defaultStore_skipFields",
        @"INMOBICMP_LastVisitTimestamp", @"INMOBICMP_GDPR_Visit_Configs",
        @"firebase-sessions-cache-key", @"ServerAPI.cacheDate",
        @"ServerAPI.cachedServices", @"triggerEvents", @"maxEventsPerBatch",
        @"com.supersonic.mediation.cvFirstSessionTimestamp",
        @"com.supersonic.mediation.networkSkanIds",
        @"SSV", @"ssaGlobalAppData", @"VungleOIT", @"currentVungleSDKVersion",
        @"com.unity.ads.lastKnownUserAgent", @"com.unity.ads.lastSystemVersion",
        @"unityads-idfi", @"com.inobi_defaultStore_SKAN",
        @"IABTCF_", @"IABGPP_", @"IABUSPrivacy_String", @"optOut",
        @"mtg_krepanKey", @"MTG_kTransformed", @"MintegralUserDefaultKeys",
        @"IS_CappingManager", @"BN_CappingManager", @"RV_CappingManager",
        @"soomlaGeneratedId", @"auid", @"uuidStringFromStore", @"GBCHash",
        @"com.inobi_defaultStore_kA", @"com.inobi_defaultStore_cip",
        @"com.inobi_defaultStore_vAK", @"com.inobi_defaultStore_inmobi.sdkversion",
        @"DeviceOSVersion", @"browserUserAgentTime", @"ua",
        @"attValue", @"IABUSPrivacy_String", @"optIn",
        nil
    ];

    // كلمات زمنية
    timeKeySubstrings = @[
        @"lastshown", @"lastvisit", @"timestamp", @"time",
        @"sit", @"cvfirstsessiontimestamp", @"browseruseragenttime",
        @"last_ad", @"lastad", @"lastadtime", @"lastVisit"
    ];

    // توليد الهوية الوهمية لهذه الجلسة
    generateFakeIdentity();
    // إنشاء UUID جديد لهذه الجلسة
    sessionAdvertisingIdentifier = [NSUUID UUID];

    // Hook C functions
    void *getifaddrs_ptr = dlsym(RTLD_DEFAULT, "getifaddrs");
    if (getifaddrs_ptr) {
        MSHookFunction(getifaddrs_ptr, (void *)hooked_getifaddrs, (void **)&original_getifaddrs);
    }

    void *scni_name_ptr = dlsym(RTLD_DEFAULT, "SCNetworkInterfaceGetName");
    if (scni_name_ptr) {
        MSHookFunction(scni_name_ptr, (void *)hooked_SCNetworkInterfaceGetName, (void **)&original_SCNetworkInterfaceGetName);
    }

    void *scni_type_ptr = dlsym(RTLD_DEFAULT, "SCNetworkInterfaceGetInterfaceType");
    if (scni_type_ptr) {
        MSHookFunction(scni_type_ptr, (void *)hooked_SCNetworkInterfaceGetInterfaceType, (void **)&original_SCNetworkInterfaceGetInterfaceType);
    }

    void *scd_proxies_ptr = dlsym(RTLD_DEFAULT, "SCDynamicStoreCopyProxies");
    if (scd_proxies_ptr) {
        MSHookFunction(scd_proxies_ptr, (void *)hooked_SCDynamicStoreCopyProxies, (void **)&original_SCDynamicStoreCopyProxies);
    }

    void *cfn_proxies_ptr = dlsym(RTLD_DEFAULT, "CFNetworkCopySystemProxySettings");
    if (cfn_proxies_ptr) {
        MSHookFunction(cfn_proxies_ptr, (void *)hooked_CFNetworkCopySystemProxySettings, (void **)&original_CFNetworkCopySystemProxySettings);
    }

    void *reach_flags_ptr = dlsym(RTLD_DEFAULT, "SCNetworkReachabilityGetFlags");
    if (reach_flags_ptr) {
        MSHookFunction(reach_flags_ptr, (void *)hooked_SCNetworkReachabilityGetFlags, (void **)&original_SCNetworkReachabilityGetFlags);
    }
}
