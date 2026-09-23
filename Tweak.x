// =================================================================
// FullSpoofer.xm - ملف واحد متكامل
// تزييف معرّفات الجهاز + IP + User-Agent عشوائي مع كل طلب
// =================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <substrate.h>

// =================================================================
// المتغيرات العامة
// =================================================================

static NSString *currentIDFA;
static NSString *currentIDFV;
static NSString *currentUDID;
static NSString *currentSerial;
static NSString *currentIMEI;
static NSString *currentFakeIP;
static NSString *currentUserAgent;

static NSLock *spoofLock;
static NSLock *ipLock;
static NSArray *ipHeaders;

// =================================================================
// 1. توليد معرّفات الجهاز
// =================================================================

static void generateNewIdentifiers(void) {
    [spoofLock lock];
    currentIDFA   = [[NSUUID UUID] UUIDString];
    currentIDFV   = [[NSUUID UUID] UUIDString];
    currentUDID   = [[NSUUID UUID] UUIDString];
    currentSerial = [NSString stringWithFormat:@"%@SPOOFED",
                     [[[NSUUID UUID] UUIDString] substringToIndex:8]];
    currentIMEI   = [NSString stringWithFormat:@"%015llu",
                     (unsigned long long)(arc4random() % 999999999999999ULL)];
    [spoofLock unlock];
    NSLog(@"[FullSpoofer] IDs → IDFA=%@ IDFV=%@", currentIDFA, currentIDFV);
}

static void rotateIdentifiers(void) {
    generateNewIdentifiers();
}

// =================================================================
// 2. توليد IP وهمي
// =================================================================

static NSString *generateRandomIP(void) {
    uint32_t ip;
    do {
        ip = arc4random();
    } while (
        ((ip & 0xFF000000) == 0x0A000000) ||
        ((ip & 0xFFF00000) == 0xAC100000) ||
        ((ip & 0xFFFF0000) == 0xC0A80000) ||
        ((ip & 0xFF000000) == 0x7F000000) ||
        ((ip & 0xFF000000) == 0xE0000000) ||
        ((ip & 0xFF000000) == 0x00000000) ||
        ((ip & 0xFF000000) == 0xFFFFFFFF)
    );

    return [NSString stringWithFormat:@"%u.%u.%u.%u",
            (ip >> 24) & 0xFF, (ip >> 16) & 0xFF,
            (ip >> 8) & 0xFF,  ip & 0xFF];
}

static void rotateFakeIP(void) {
    [ipLock lock];
    currentFakeIP = generateRandomIP();
    [ipLock unlock];
    NSLog(@"[FullSpoofer] IP → %@", currentFakeIP);
}

// =================================================================
// 3. توليد User-Agent عشوائي لنظام iOS
// =================================================================

static void rotateUserAgent(void) {
    // --- إصدارات iOS ---
    NSArray *iosVersions = @[
        @"15_0", @"15_1", @"15_2", @"15_3", @"15_4", @"15_5", @"15_6", @"15_7",
        @"16_0", @"16_1", @"16_2", @"16_3", @"16_4", @"16_5", @"16_6", @"16_7",
        @"17_0", @"17_1", @"17_2", @"17_3", @"17_4", @"17_4_1", @"17_5", @"17_5_1", @"17_6",
        @"18_0", @"18_1", @"18_2"
    ];

    // --- إصدارات WebKit ---
    NSArray *webkitVersions = @[
        @"605.1.15", @"605.1.15", @"605.1.15", @"605.1.15",
        @"606.1.15", @"607.1.15"
    ];

    // --- إصدارات Safari ---
    NSArray *safariVersions = @[
        @"15.0", @"15.1", @"15.5", @"15.6",
        @"16.0", @"16.1", @"16.5", @"16.6",
        @"17.0", @"17.1", @"17.4", @"17.5", @"17.6",
        @"18.0"
    ];

    // --- إصدارات Chrome iOS ---
    NSArray *chromeVersions = @[
        @"120.0.6099.119", @"121.0.6167.66", @"122.0.6261.62",
        @"123.0.6312.52", @"124.0.6367.111", @"125.0.6422.80",
        @"126.0.6478.54", @"127.0.6533.77", @"128.0.6613.92"
    ];

    // --- إصدارات Firefox iOS ---
    NSArray *firefoxVersions = @[
        @"119.0", @"120.0", @"121.0", @"122.0",
        @"123.0", @"124.0", @"125.0", @"126.0", @"127.0"
    ];

    // --- إصدارات Edge iOS ---
    NSArray *edgeVersions = @[
        @"120.0.2210.86", @"121.0.2277.86", @"122.0.2365.68",
        @"123.0.2420.72", @"124.0.2478.60"
    ];

    // --- نوع الجهاز ---
    NSArray *devices = @[ @"iPhone", @"iPhone", @"iPhone", @"iPhone", @"iPad" ];

    // --- اختيار عشوائي ---
    NSString *iosVersion    = iosVersions[arc4random_uniform((uint32_t)iosVersions.count)];
    NSString *webkitVersion = webkitVersions[arc4random_uniform((uint32_t)webkitVersions.count)];
    NSString *device        = devices[arc4random_uniform((uint32_t)devices.count)];

    uint32_t browserChoice = arc4random_uniform(100);
    NSString *ua;

    if (browserChoice < 50) {
        // Safari ~50%
        NSString *ver = safariVersions[arc4random_uniform((uint32_t)safariVersions.count)];
        ua = [NSString stringWithFormat:
              @"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/%@ (KHTML, like Gecko) Version/%@ Mobile/15E148 Safari/604.1",
              device, iosVersion, webkitVersion, ver];
    }
    else if (browserChoice < 75) {
        // Chrome iOS ~25%
        NSString *ver = chromeVersions[arc4random_uniform((uint32_t)chromeVersions.count)];
        ua = [NSString stringWithFormat:
              @"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/%@ (KHTML, like Gecko) CriOS/%@ Mobile/15E148 Safari/604.1",
              device, iosVersion, webkitVersion, ver];
    }
    else if (browserChoice < 90) {
        // Firefox iOS ~15%
        NSString *ver = firefoxVersions[arc4random_uniform((uint32_t)firefoxVersions.count)];
        ua = [NSString stringWithFormat:
              @"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/%@ (KHTML, like Gecko) FxiOS/%@ Mobile/15E148 Safari/605.1.15",
              device, iosVersion, webkitVersion, ver];
    }
    else {
        // Edge iOS ~10%
        NSString *ver = edgeVersions[arc4random_uniform((uint32_t)edgeVersions.count)];
        ua = [NSString stringWithFormat:
              @"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/%@ (KHTML, like Gecko) EdgiOS/%@ Mobile/15E148 Safari/604.1",
              device, iosVersion, webkitVersion, ver];
    }

    [ipLock lock];
    currentUserAgent = ua;
    [ipLock unlock];

    NSLog(@"[FullSpoofer] UA → %@", currentUserAgent);
}

// =================================================================
// 4. حقن الترويسات (IP + User-Agent)
// =================================================================

static NSURLRequest *injectIPHeaders(NSURLRequest *request) {
    NSMutableURLRequest *mutableRequest;
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        mutableRequest = (NSMutableURLRequest *)request;
    } else {
        mutableRequest = [request mutableCopy];
    }

    [ipLock lock];
    NSString *fakeIP = currentFakeIP;
    NSString *fakeUA = currentUserAgent;
    [ipLock unlock];

    // --- IP وهمي في كل الترويسات ---
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Client-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Originating-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Remote-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Remote-Addr"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"Forwarded"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"True-Client-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"CF-Connecting-IP"];
    [mutableRequest setValue:fakeIP forHTTPHeaderField:@"X-Cluster-Client-IP"];

    // --- User-Agent وهمي ---
    if (fakeUA) {
        [mutableRequest setValue:fakeUA forHTTPHeaderField:@"User-Agent"];
    }

    return mutableRequest;
}

// =================================================================
// 5. Hooks عبر Logos
// =================================================================

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    rotateIdentifiers();
    return [[NSUUID alloc] initWithUUIDString:currentIDFA];
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentIDFV];
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *lowerField = [field lowercaseString];

    // --- اعتراض User-Agent ---
    if ([lowerField isEqualToString:@"user-agent"]) {
        [ipLock lock];
        NSString *fakeUA = currentUserAgent;
        [ipLock unlock];
        %orig(fakeUA, field);
        return;
    }

    // --- اعتراض ترويسات IP ---
    for (NSString *ipHeader in ipHeaders) {
        if ([lowerField isEqualToString:ipHeader]) {
            [ipLock lock];
            NSString *fake = currentFakeIP;
            [ipLock unlock];
            %orig(fake, field);
            return;
        }
    }
    %orig;
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    NSString *lowerField = [field lowercaseString];

    if ([lowerField isEqualToString:@"user-agent"]) {
        [ipLock lock];
        NSString *fakeUA = currentUserAgent;
        [ipLock unlock];
        return fakeUA;
    }

    for (NSString *ipHeader in ipHeaders) {
        if ([lowerField isEqualToString:ipHeader]) {
            [ipLock lock];
            NSString *fake = currentFakeIP;
            [ipLock unlock];
            return fake;
        }
    }
    return %orig;
}
%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    rotateIdentifiers();
    rotateFakeIP();
    rotateUserAgent();
    NSURLRequest *newRequest = injectIPHeaders(request);
    return %orig(newRequest, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    rotateIdentifiers();
    rotateFakeIP();
    rotateUserAgent();
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request = (NSMutableURLRequest *)injectIPHeaders(request);
    return _logos_orig$_ungrouped$NSURLSession$dataTaskWithRequest$completionHandler$(
        self, @selector(dataTaskWithRequest:completionHandler:), request, completionHandler
    );
}

%end

%hook NSURLConnection
+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    rotateIdentifiers();
    rotateFakeIP();
    rotateUserAgent();
    NSURLRequest *newRequest = injectIPHeaders(request);
    return %orig(newRequest, delegate);
}
%end

// =================================================================
// 6. Hooks دوال C
// =================================================================

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus new_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    return errSecDuplicateItem;
}

static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus new_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    if (result) {
        NSDictionary *queryDict = (__bridge NSDictionary *)query;
        id returnData = queryDict[(__bridge id)kSecReturnData];
        if ([returnData boolValue]) {
            NSData *fakeData = [currentUDID dataUsingEncoding:NSUTF8StringEncoding];
            *result = (__bridge_retained CFTypeRef)fakeData;
            return errSecSuccess;
        }
    }
    return orig_SecItemCopyMatching(query, result);
}

typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef);
static MGCopyAnswerFunc orig_MGCopyAnswer;

static CFTypeRef new_MGCopyAnswer(CFStringRef key) {
    NSString *keyStr = (__bridge NSString *)key;

    if ([keyStr isEqualToString:@"UniqueDeviceID"])
        return (__bridge_retained CFTypeRef)currentUDID;
    if ([keyStr isEqualToString:@"SerialNumber"])
        return (__bridge_retained CFTypeRef)currentSerial;
    if ([keyStr isEqualToString:@"InternationalMobileEquipmentIdentity"])
        return (__bridge_retained CFTypeRef)currentIMEI;
    if ([keyStr isEqualToString:@"AdvertisingIdentifier"])
        return (__bridge_retained CFTypeRef)currentIDFA;
    if ([keyStr isEqualToString:@"IdentifierForVendor"])
        return (__bridge_retained CFTypeRef)currentIDFV;

    return orig_MGCopyAnswer(key);
}

// =================================================================
// 7. نقطة الدخول
// =================================================================

%ctor {
    spoofLock = [[NSLock alloc] init];
    ipLock    = [[NSLock alloc] init];

    generateNewIdentifiers();
    rotateFakeIP();
    rotateUserAgent();

    ipHeaders = @[
        @"x-forwarded-for", @"x-real-ip", @"x-client-ip",
        @"x-originating-ip", @"x-remote-ip", @"x-remote-addr",
        @"client-ip", @"forwarded", @"true-client-ip",
        @"cf-connecting-ip", @"x-cluster-client-ip"
    ];

    NSLog(@"[FullSpoofer] ==============================");
    NSLog(@"[FullSpoofer] Initializing...");
    NSLog(@"[FullSpoofer] ==============================");

    // --- MGCopyAnswer ---
    void *mgHandle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mgHandle) {
        void *mgPtr = dlsym(mgHandle, "MGCopyAnswer");
        if (mgPtr) {
            MSHookFunction(mgPtr, (void *)new_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
            NSLog(@"[FullSpoofer] ✓ MGCopyAnswer hooked");
        }
    }

    // --- Keychain ---
    void *secHandle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
    if (secHandle) {
        void *addPtr = dlsym(secHandle, "SecItemAdd");
        if (addPtr) {
            MSHookFunction(addPtr, (void *)new_SecItemAdd, (void **)&orig_SecItemAdd);
            NSLog(@"[FullSpoofer] ✓ SecItemAdd hooked");
        }

        void *copyPtr = dlsym(secHandle, "SecItemCopyMatching");
        if (copyPtr) {
            MSHookFunction(copyPtr, (void *)new_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching);
            NSLog(@"[FullSpoofer] ✓ SecItemCopyMatching hooked");
        }
    }

    NSLog(@"[FullSpoofer] ✓ All hooks installed");
    NSLog(@"[FullSpoofer] ==============================");
}
