#import <substrate.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <ifaddrs.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <AdSupport/ASIdentifierManager.h>
#import <NetworkExtension/NetworkExtension.h>
#import <Security/Security.h>

// ----------------------------------------------------------------------
// 1. Configuration & Constants
// ----------------------------------------------------------------------

static NSArray<NSString *> *vpnInterfaceNameSubstrings;
static NSArray<NSString *> *ipLookupHosts;
static NSArray<NSString *> *atlantaZipCodes;
static NSArray<NSDictionary *> *ispData;

// استخدام NSSet للبحث السريع
static NSSet<NSString *> *timeIndicators;
static NSSet<NSString *> *adIndicators;

// استثناءات Keychain
static NSSet<NSString *> *keychainExcludedServices;
static NSSet<NSString *> *keychainExcludedAccounts;
static NSSet<NSString *> *suspiciousKeychainServices;
static NSSet<NSString *> *suspiciousKeychainAccounts;

// Keys for associated objects
static char kFakeTaskKey;
static char kFakeCompletionKey;

// نطاق IP السكني
static uint32_t residentialBase = 0xAC380000;
static uint32_t residentialMask = 0xFFF80000;

// الهوية الوهمية
static NSString *fakeIP = nil;
static NSString *fakeZip = nil;
static double fakeLat = 0;
static double fakeLon = 0;
static NSString *fakeISPName = nil;
static NSString *fakeISPOrg = nil;
static NSString *fakeISPAS = nil;

// UUID جديد لكل جلسة
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
    return [NSString stringWithFormat:
        @"{\"status\":\"success\",\"country\":\"United States\",\"countryCode\":\"US\","
        "\"region\":\"GA\",\"regionName\":\"Georgia\",\"city\":\"Atlanta\","
        "\"zip\":\"%@\",\"lat\":%.4f,\"lon\":%.4f,\"timezone\":\"America/New_York\","
        "\"isp\":\"%@\",\"org\":\"%@\",\"as\":\"%@\",\"query\":\"%@\","
        "\"proxy\":false,\"hosting\":false,\"vpn\":false,\"tor\":false,\"datacenter\":false}",
        fakeZip, fakeLat, fakeLon, fakeISPName, fakeISPOrg, fakeISPAS, fakeIP];
}

static BOOL isAdTimeKey(NSString *key) {
    // فحص سريع باستخدام NSSet
    // نمر على مكونات المفتاح بدلاً من البحث النصي البطيء
    static NSArray<NSString *> *keyComponents = nil;
    if (!keyComponents) {
        keyComponents = @[@"lastshown", @"lastvisit", @"timestamp", @"time", @"sit",
                         @"cvfirstsessiontimestamp", @"browseruseragenttime", @"last_ad",
                         @"lastad", @"lastadtime", @"date", @"first", @"initial", @"launch"];
    }
    BOOL hasTime = NO;
    for (NSString *component in keyComponents) {
        if ([key rangeOfString:component options:NSCaseInsensitiveSearch].location != NSNotFound) {
            hasTime = YES;
            break;
        }
    }
    if (!hasTime) return NO;

    // فحص الإعلان بنفس الطريقة
    for (NSString *ad in adIndicators) {
        if ([key rangeOfString:ad options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static long long randomTimeBetween24And48HoursAgoMillis(void) {
    long long minMillis = 24LL * 3600000;
    long long maxMillis = 48LL * 3600000;
    long long randomMillis = minMillis + arc4random_uniform((uint32_t)(maxMillis - minMillis + 1));
    long long currentMillis = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    return currentMillis - randomMillis;
}

static BOOL shouldFakeKeychain(CFDictionaryRef query) {
    if (!query) return NO;
    NSDictionary *dict = (__bridge NSDictionary *)query;
    NSString *service = dict[(__bridge id)kSecAttrService];
    NSString *account = dict[(__bridge id)kSecAttrAccount];

    if (service && [keychainExcludedServices containsObject:service]) return NO;
    if (account && [keychainExcludedAccounts containsObject:account]) return NO;

    if (service && [suspiciousKeychainServices containsObject:service]) return YES;
    if (account && [suspiciousKeychainAccounts containsObject:account]) return YES;

    // فحص الكلمات العامة بأسلوب أسرع
    for (NSString *word in @[@"appmetrica", @"firebase", @"installations", @"googlesso",
                             @"generateddeviceidentifier", @"unity", @"vungle", @"inmobi",
                             @"supersonic", @"ironsource", @"admob", @"mintegral",
                             @"applovin", @"tapjoy", @"chartboost"]) {
        if (service && [service rangeOfString:word options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
        if (account && [account rangeOfString:word options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

// ----------------------------------------------------------------------
// 3. Original C Function Pointers
// ----------------------------------------------------------------------

static int (*original_getifaddrs)(struct ifaddrs **);
static CFStringRef (*original_SCNetworkInterfaceGetName)(SCNetworkInterfaceRef);
static CFStringRef (*original_SCNetworkInterfaceGetInterfaceType)(SCNetworkInterfaceRef);
static OSStatus (*original_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*original_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*original_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*original_SecItemDelete)(CFDictionaryRef);

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

static OSStatus hooked_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    if (shouldFakeKeychain(query)) return errSecItemNotFound;
    return original_SecItemCopyMatching(query, result);
}

static OSStatus hooked_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    if (shouldFakeKeychain(attributes)) return errSecSuccess;
    return original_SecItemAdd(attributes, result);
}

static OSStatus hooked_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrs) {
    if (shouldFakeKeychain(query)) return errSecSuccess;
    return original_SecItemUpdate(query, attrs);
}

static OSStatus hooked_SecItemDelete(CFDictionaryRef query) {
    if (shouldFakeKeychain(query)) return errSecSuccess;
    return original_SecItemDelete(query);
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
// 6. NSURLSession Interception (فحوصات IP فقط)
// ----------------------------------------------------------------------

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                           completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *host = request.URL.host.lowercaseString;
    BOOL shouldIntercept = NO;
    for (NSString *h in ipLookupHosts) {
        if ([host hasSuffix:h] || [host isEqualToString:h]) {
            shouldIntercept = YES;
            break;
        }
    }

    if (shouldIntercept) {
        NSURL *dummyURL = [NSURL URLWithString:@"http://127.0.0.1:1"];
        NSURLRequest *dummyRequest = [NSURLRequest requestWithURL:dummyURL];
        NSURLSessionDataTask *task = %orig(dummyRequest, ^(NSData *data, NSURLResponse *response, NSError *error) {});
        if (task) {
            objc_setAssociatedObject(task, &kFakeTaskKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(task, &kFakeCompletionKey, completionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        return task;
    } else {
        return %orig;
    }
}

%end

%hook NSURLSessionDataTask

- (void)resume {
    NSNumber *isFake = objc_getAssociatedObject(self, &kFakeTaskKey);
    if (isFake && [isFake boolValue]) {
        void (^completion)(NSData *, NSURLResponse *, NSError *) = objc_getAssociatedObject(self, &kFakeCompletionKey);
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *data = [generateFakeIPResponse() dataUsingEncoding:NSUTF8StringEncoding];
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
// 7. IDFA جديد (اختياري)
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
// 8. NSUserDefaults – فقط مفاتيح الوقت والإعلانات معًا
// ----------------------------------------------------------------------

%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        return @(randomTimeBetween24And48HoursAgoMillis());
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        return (NSInteger)randomTimeBetween24And48HoursAgoMillis();
    }
    return %orig;
}

- (double)doubleForKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        long long millis = randomTimeBetween24And48HoursAgoMillis();
        return (double)millis / 1000.0;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        return;
    }
    %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        return;
    }
    %orig;
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName {
    if (isAdTimeKey(defaultName)) {
        return;
    }
    %orig;
}

%end

// ----------------------------------------------------------------------
// 9. Constructor
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

    // مؤشرات الوقت والإعلان كـ NSSet للبحث السريع
    timeIndicators = [NSSet setWithObjects:
        @"lastshown", @"lastvisit", @"timestamp", @"time", @"sit",
        @"cvfirstsessiontimestamp", @"browseruseragenttime", @"last_ad",
        @"lastad", @"lastadtime", @"date", @"first", @"initial", @"launch", nil
    ];

    adIndicators = [NSSet setWithObjects:
        @"capping", @"supersonic", @"vungle", @"inobi", @"inmobi", @"unity",
        @"ironsource", @"admob", @"google", @"firebase", @"analytics",
        @"tracking", @"consent", @"gdpr", @"ccpa", @"skad", @"mintegral",
        @"applovin", @"tapjoy", @"chartboost", @"facebook", @"audience",
        @"network", @"mediation", @"waterfall", @"placement", @"campaign",
        @"creative", @"cache", @"config", @"identifier", @"device", @"uuid",
        @"idfa", @"idfv", @"vendor", @"advertising", @"att", @"opt",
        @"privacy", @"log", @"event", @"batch", @"queue", @"usage",
        @"limit", @"cap", @"frequency", @"count", @"shown", @"seen",
        @"completed", @"watched", @"rewarded", @"credits", @"balance",
        @"points", @"profile", @"soomla", @"auid", @"uuidstring", @"gbchash",
        @"deviceosversion", @"browseruseragenttime", @"ua", @"attvalue", @"optout", @"optin", nil
    ];

    // استثناءات Keychain
    keychainExcludedServices = [NSSet setWithObjects:@"com.codebysms", nil];
    keychainExcludedAccounts = [NSSet setWithObjects:@"userIDKey", @"accessTokenKey", @"Accounts",
                                 @"User.id", @"User.token", @"User.balance", nil];

    suspiciousKeychainServices = [NSSet setWithObjects:
        @"io.appmetrica.service.application",
        @"com.google.sso.GeneratedDeviceIdentifier",
        @"wiki.qaq.Asspp.DeviceIdentifier",
        @"wiki.qaq.Asspp.Accounts",
        @"com.firebase.FIRInstallations.installations",
        @"AMADeviceDescription",
        @"D7CA1CE6DE13787FD151D81C8E2C8C56", nil
    ];

    suspiciousKeychainAccounts = [NSSet setWithObjects:
        @"AMAMetricaPersistentConfigurationDeviceIDStorageKey",
        @"AMAMetricaPersistentConfigurationDeviceIDHashStorageKey",
        @"GeneratedDeviceIdentifier",
        @"DeviceIdentifier",
        @"AMAAppIdentifierPrefix",
        @"1:580931174328:ios:bd844db744cd3c48a1194d__FIRAPP_DEFAULT",
        @"1:755541669657:ios:4d6d5a5ce71e9d30__FIRAPP_DEFAULT",
        @"D7CA1CE6DE13787FD151D81C8E2C8C56", nil
    ];

    generateFakeIdentity();
    sessionAdvertisingIdentifier = [NSUUID UUID];

    // Hook getifaddrs
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

    void *secCopy = dlsym(RTLD_DEFAULT, "SecItemCopyMatching");
    if (secCopy) MSHookFunction(secCopy, (void *)hooked_SecItemCopyMatching, (void **)&original_SecItemCopyMatching);

    void *secAdd = dlsym(RTLD_DEFAULT, "SecItemAdd");
    if (secAdd) MSHookFunction(secAdd, (void *)hooked_SecItemAdd, (void **)&original_SecItemAdd);

    void *secUpdate = dlsym(RTLD_DEFAULT, "SecItemUpdate");
    if (secUpdate) MSHookFunction(secUpdate, (void *)hooked_SecItemUpdate, (void **)&original_SecItemUpdate);

    void *secDelete = dlsym(RTLD_DEFAULT, "SecItemDelete");
    if (secDelete) MSHookFunction(secDelete, (void *)hooked_SecItemDelete, (void **)&original_SecItemDelete);
}
