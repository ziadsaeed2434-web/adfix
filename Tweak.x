#import <substrate.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <ifaddrs.h>
#import <dlfcn.h>

// ----------------------------------------------------------------------
// 1. Configuration & Constants
// ----------------------------------------------------------------------

static NSArray<NSString *> *vpnInterfaceNameSubstrings;
static NSArray<NSString *> *ipLookupHosts;
static NSArray<NSString *> *atlantaZipCodes;
static NSArray<NSDictionary *> *ispData;

// ----------------------------------------------------------------------
// 2. Dynamic Fake IP Response Generator (Atlanta, GA)
// ----------------------------------------------------------------------

static NSString *generateFakeIPResponse(void) {
    NSArray<NSNumber *> *secondOctets = @[@56, @57, @59];
    int second = [secondOctets[arc4random_uniform((uint32_t)secondOctets.count)] intValue];
    int third = 1 + arc4random_uniform(254);
    int fourth = 1 + arc4random_uniform(254);
    NSString *ip = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];

    NSString *zip = atlantaZipCodes[arc4random_uniform((uint32_t)atlantaZipCodes.count)];

    double lat = 33.65 + ((double)arc4random_uniform(3000) / 10000.0);
    double lon = -84.55 + ((double)arc4random_uniform(3000) / 10000.0);

    NSDictionary *isp = ispData[arc4random_uniform((uint32_t)ispData.count)];
    NSString *ispName = isp[@"name"];
    NSString *ispOrg = isp[@"org"];
    NSString *ispAS = isp[@"as"];

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
        zip, lat, lon, ispName, ispOrg, ispAS, ip];
    return json;
}

// ----------------------------------------------------------------------
// 3. Original C Function Pointers
// ----------------------------------------------------------------------

static int (*original_getifaddrs)(struct ifaddrs **);
static CFStringRef (*original_SCNetworkInterfaceGetName)(SCNetworkInterfaceRef);
static CFStringRef (*original_SCNetworkInterfaceGetInterfaceType)(SCNetworkInterfaceRef);
static CFDictionaryRef (*original_SCDynamicStoreCopyProxies)(SCDynamicStoreRef);
static CFDictionaryRef (*original_CFNetworkCopySystemProxySettings)(void);

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
    if (isVPN) {
        return CFSTR("en0");
    }
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
    if (isVPN) {
        // استخدام سلسلة نصية تمثل نوع واجهة عادي (غير متوفر كثابت على iOS)
        return CFSTR("WiFi");
    }
    return originalType;
}

static CFDictionaryRef hooked_SCDynamicStoreCopyProxies(SCDynamicStoreRef store) {
    // إرجاع قاموس فارغ = لا يوجد بروكسي
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

// ----------------------------------------------------------------------
// 5. Fake NSURLSessionDataTask
// ----------------------------------------------------------------------

@interface FakeDataTask : NSURLSessionDataTask
@property (nonatomic, copy) void (^completionHandler)(NSData *, NSURLResponse *, NSError *);
@property (nonatomic, strong) NSURLRequest *request;
@end

@implementation FakeDataTask

- (instancetype)initWithRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    self = [super init];
    if (self) {
        _request = request;
        _completionHandler = [handler copy];
    }
    return self;
}

- (void)resume {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.completionHandler) {
            NSString *json = generateFakeIPResponse();
            NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:@"HTTP/1.1"
                                                                    headerFields:@{@"Content-Type": @"application/json"}];
            self.completionHandler(data, response, nil);
            self.completionHandler = nil;
        }
    });
}

- (void)cancel {}
- (void)suspend {}

- (void)dealloc {
    self.completionHandler = nil;
    [super dealloc];
}

@end

// ----------------------------------------------------------------------
// 6. Hook NSURLSession
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
        return [[FakeDataTask alloc] initWithRequest:request
                                  completionHandler:completionHandler];
    } else {
        return %orig;
    }
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                       completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    return [self dataTaskWithRequest:request completionHandler:completionHandler];
}

%end

// ----------------------------------------------------------------------
// 7. Constructor
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
}
