// Tweak.xm
// iOS Tweak: Auto IP Injection (172.59.x.x), IDFA Spoofing,
// Keychain Cleanup with SAFE preservation of app.getsmscode/tokenKey
// (العنصر المحفوظ لا يُلمس إطلاقاً - لا حذف ولا استعادة)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// ==================================================================
// 1. HELPERS
// ==================================================================

// توليد IP عشوائي ضمن النطاق 172.59.x.x
static NSString *generateRandomIP(void) {
    uint32_t o3 = arc4random_uniform(256);
    uint32_t o4 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"172.59.%u.%u", o3, o4];
}

// توليد UUID جديد
static NSString *generateRandomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

// حقن كل هيدرات الـ IP المعروفة في الـ request
static void injectSpoofedHeaders(NSMutableURLRequest *req) {
    if (!req || ![req isKindOfClass:[NSMutableURLRequest class]]) return;
    @try {
        NSString *ip = generateRandomIP();
        [req setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [req setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [req setValue:ip forHTTPHeaderField:@"X-Client-IP"];
        [req setValue:ip forHTTPHeaderField:@"X-Originating-IP"];
        [req setValue:ip forHTTPHeaderField:@"CF-Connecting-IP"];
        [req setValue:ip forHTTPHeaderField:@"True-Client-IP"];
        [req setValue:[NSString stringWithFormat:@"for=%@", ip] forHTTPHeaderField:@"Forwarded"];
        [req setValue:ip forHTTPHeaderField:@"Client-IP"];
    } @catch (NSException *e) {
        NSLog(@"[Tweak] injectSpoofedHeaders error: %@", e);
    }
}

// ==================================================================
// 2. HOOK NSMutableURLRequest
// ==================================================================

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *lower = [field lowercaseString];
    if ([lower containsString:@"forwarded"] ||
        [lower containsString:@"real-ip"] ||
        [lower containsString:@"client-ip"] ||
        [lower containsString:@"originating"]) {
        value = generateRandomIP();
    }
    %orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)headerFields {
    NSMutableDictionary *h = [headerFields mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *ip = generateRandomIP();
    h[@"X-Forwarded-For"]   = ip;
    h[@"X-Real-IP"]         = ip;
    h[@"X-Client-IP"]       = ip;
    h[@"X-Originating-IP"]  = ip;
    h[@"CF-Connecting-IP"]  = ip;
    h[@"True-Client-IP"]    = ip;
    h[@"Forwarded"]         = [NSString stringWithFormat:@"for=%@", ip];
    h[@"Client-IP"]         = ip;
    %orig(h);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *lower = [field lowercaseString];
    if ([lower containsString:@"forwarded"] ||
        [lower containsString:@"real-ip"] ||
        [lower containsString:@"client-ip"]) {
        value = generateRandomIP();
    }
    %orig(value, field);
}

// نحقن الهيدرات في أي نسخة من الـ request (مهم جداً لمكتبات مثل AFNetworking)
- (id)copyWithZone:(NSZone *)zone {
    id copy = %orig(zone);
    injectSpoofedHeaders(copy);
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    id copy = %orig(zone);
    injectSpoofedHeaders(copy);
    return copy;
}

%end

// ==================================================================
// 3. HOOK NSURLRequest (الكلاس الأساسي)
// ==================================================================

%hook NSURLRequest

- (NSDictionary *)allHTTPHeaderFields {
    NSDictionary *origDict = %orig;
    NSMutableDictionary *mutable = [origDict mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *ip = generateRandomIP();
    mutable[@"X-Forwarded-For"]  = ip;
    mutable[@"X-Real-IP"]        = ip;
    mutable[@"X-Client-IP"]      = ip;
    mutable[@"X-Originating-IP"] = ip;
    return mutable;
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    NSString *lower = [field lowercaseString];
    if ([lower containsString:@"forwarded"] ||
        [lower containsString:@"real-ip"] ||
        [lower containsString:@"client-ip"]) {
        return generateRandomIP();
    }
    return %orig(field);
}

%end

// ==================================================================
// 4. HOOK NSURLSession
// ==================================================================

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    injectSpoofedHeaders(req);
    return [self dataTaskWithRequest:req completionHandler:completionHandler];
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    injectSpoofedHeaders(req);
    return [self dataTaskWithRequest:req];
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)bodyData
                                completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, bodyData, completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                    completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, completionHandler);
}

%end

// ==================================================================
// 5. HOOK NSURLConnection (API القديم)
// ==================================================================

%hook NSURLConnection

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, delegate);
}

- (instancetype)initWithRequest:(NSURLRequest *)request
                       delegate:(id)delegate
               startImmediately:(BOOL)startImmediately {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, delegate, startImmediately);
}

- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        injectSpoofedHeaders((NSMutableURLRequest *)request);
    }
    return %orig(request, delegate);
}

%end

// ==================================================================
// 6. IDFA SPOOFING
// ==================================================================

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:generateRandomUUID()];
}

%end

%hook UIDevice

- (NSString *)uniqueIdentifier {
    return generateRandomUUID();
}

%end

// ==================================================================
// 7. KEYCHAIN CLEANUP كل 5 ثواني - بدون لمس العنصر المحفوظ
// ==================================================================

static NSString *const kPreservedService = @"app.getsmscode";
static NSString *const kPreservedAccount = @"tokenKey";
static dispatch_source_t gKeychainTimer = NULL;

// هل هذا العنصر هو اللي لازم نحميه؟
static BOOL isPreservedItem(NSDictionary *attrs) {
    if (!attrs) return NO;
    NSString *service = attrs[(__bridge id)kSecAttrService];
    NSString *account = attrs[(__bridge id)kSecAttrAccount];

    // نحمي العنصر لو تطابق الـ Service
    if (service && [service isEqualToString:kPreservedService]) {
        // نحن نحمي أي عنصر تحت هذا الـ service
        // حتى لو الـ account مختلف، احتياط إضافي
        if (!account || [account isEqualToString:kPreservedAccount]) {
            return YES;
        }
        return YES;
    }
    return NO;
}

static void performKeychainCleanup(void) {
    @autoreleasepool {
        // 1) نجلب كل عناصر generic password مع الـ attributes
        NSDictionary *query = @{
            (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitAll,
            (__bridge id)kSecReturnAttributes: @YES,
        };

        CFTypeRef result = NULL;
        OSStatus s = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

        if (s != errSecSuccess || result == NULL) {
            if (result) CFRelease(result);
            return;
        }

        NSArray *items = (__bridge NSArray *)result;

        // 2) نمر على كل عنصر ونحذف فقط اللي مو محفوظ
        for (NSDictionary *attrs in items) {
            @autoreleasepool {
                // تخطّى العنصر المحفوظ — لا يُلمس إطلاقاً
                if (isPreservedItem(attrs)) {
                    NSLog(@"[Tweak] Preserving keychain item: service=%@, account=%@",
                          attrs[(__bridge id)kSecAttrService],
                          attrs[(__bridge id)kSecAttrAccount]);
                    continue;
                }

                // نبني استعلام حذف دقيق لهذا العنصر فقط
                NSMutableDictionary *delQuery = [NSMutableDictionary dictionary];
                delQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

                id service     = attrs[(__bridge id)kSecAttrService];
                id account     = attrs[(__bridge id)kSecAttrAccount];
                id accessGroup = attrs[(__bridge id)kSecAttrAccessGroup];
                id generic     = attrs[(__bridge id)kSecAttrGeneric];

                if (service)     delQuery[(__bridge id)kSecAttrService]     = service;
                if (account)     delQuery[(__bridge id)kSecAttrAccount]     = account;
                if (accessGroup) delQuery[(__bridge id)kSecAttrAccessGroup] = accessGroup;
                if (generic)     delQuery[(__bridge id)kSecAttrGeneric]     = generic;

                OSStatus ds = SecItemDelete((__bridge CFDictionaryRef)delQuery);
                if (ds != errSecSuccess && ds != errSecItemNotFound) {
                    NSLog(@"[Tweak] delete item failed: %d for service=%@ account=%@",
                          (int)ds, service, account);
                }
            }
        }

        CFRelease(result);
    }
}

// (اختياري) اطبع كل عناصر الـ Keychain عشان تتأكد من الأسماء
// استخدمها مرة وحدة أول تشغيل، بعدين علّقها
static void dumpAllKeychainItems(void) {
    NSDictionary *q = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitAll,
        (__bridge id)kSecReturnAttributes: @YES,
    };
    CFTypeRef r = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &r) == errSecSuccess && r) {
        NSArray *items = (__bridge NSArray *)r;
        for (NSDictionary *a in items) {
            NSLog(@"[Tweak][DUMP] service=%@ | account=%@ | group=%@",
                  a[(__bridge id)kSecAttrService],
                  a[(__bridge id)kSecAttrAccount],
                  a[(__bridge id)kSecAttrAccessGroup]);
        }
        CFRelease(r);
    }
}

// ==================================================================
// 8. تشغيل المؤقت تلقائياً عند بدء التطبيق
// ==================================================================

%ctor {
    if (gKeychainTimer != NULL) return;

    // (اختياري) اطبع العناصر الموجودة مرة وحدة عند الإقلاع
    // dumpAllKeychainItems();

    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    gKeychainTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);

    uint64_t interval = 5ull * NSEC_PER_SEC;
    dispatch_source_set_timer(gKeychainTimer,
                              dispatch_time(DISPATCH_TIME_NOW, interval),
                              interval,
                              1ull * NSEC_PER_SEC);

    dispatch_source_set_event_handler(gKeychainTimer, ^{
        performKeychainCleanup();
    });

    dispatch_resume(gKeychainTimer);
}
