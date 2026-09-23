// =================================================================
// FullSpoofer.xm - ملف واحد متكامل
// تزييف معرّفات الجهاز + IP في الترويسات مع كل طلب
// لا يحتاج أي ملفات أو مكتبات خارجية
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
                     [[NSUUID UUID] UUIDString].substringToIndex(8)];
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
// 3. حقن ترويسات IP في الطلب
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
    [ipLock unlock];

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

    return mutableRequest;
}

// =================================================================
// 4. Hooks عبر Logos
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
    NSURLRequest *newRequest = injectIPHeaders(request);
    return %orig(newRequest, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    rotateIdentifiers();
    rotateFakeIP();
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request = (NSMutableURLRequest *)injectIPHeaders(request);
    return %orig(request, completionHandler);
}
%end

%hook NSURLConnection
+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    rotateIdentifiers();
    rotateFakeIP();
    NSURLRequest *newRequest = injectIPHeaders(request);
    return %orig(newRequest, delegate);
}
%end

// =================================================================
// 5. Hooks دوال C عبر Substrate
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
// 6. نقطة الدخول
// =================================================================

%ctor {
    spoofLock = [[NSLock alloc] init];
    ipLock    = [[NSLock alloc] init];

    generateNewIdentifiers();
    rotateFakeIP();

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
