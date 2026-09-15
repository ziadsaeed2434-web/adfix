// Tweak.xm
// iOS Tweak: Auto IP Injection (172.59.x.x), IDFA Spoofing,
// Keychain Cleanup with Preservation of app.getsmscode/tokenKey

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
// 7. KEYCHAIN CLEANUP كل 5 ثواني مع الحفاظ على tokenKey
// ==================================================================

static NSString *const kPreservedService = @"app.getsmscode";
static NSString *const kPreservedAccount = @"tokenKey";
static dispatch_source_t gKeychainTimer = NULL;

// نسخة احتياطية للعنصر المطلوب الحفاظ عليه
static NSDictionary *backupPreservedItem(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:      kPreservedService,
        (__bridge id)kSecAttrAccount:      kPreservedAccount,
        (__bridge id)kSecReturnData:       @YES,
        (__bridge id)kSecReturnAttributes: @YES,
    };
    CFTypeRef result = NULL;
    OSStatus s = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (s == errSecSuccess && result != NULL) {
        NSDictionary *dict = (__bridge NSDictionary *)result;
        CFRelease(result); // تحرير يدوي لأننا في non-ARC
        return dict;
    }
    return nil;
}

// استعادة العنصر المحفوظ
static void restorePreservedItem(NSDictionary *backup) {
    if (!backup) return;
    NSMutableDictionary *add = [backup mutableCopy];
    add[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    // نحذف أي نسخة قديمة (احتياطي) ثم نضيف
    SecItemDelete((__bridge CFDictionaryRef)add);
    OSStatus s = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    if (s != errSecSuccess) {
        NSLog(@"[Tweak] restorePreservedItem failed: %d", (int)s);
    }
}

// الدالة الكاملة للتنظيف
static void performKeychainCleanup(void) {
    @autoreleasepool {
        // 1. نسخ احتياطي للعنصر المطلوب
        NSDictionary *backup = backupPreservedItem();

        // 2. حذف كل عناصر generic password
        NSDictionary *del = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword
        };
        OSStatus ds = SecItemDelete((__bridge CFDictionaryRef)del);
        if (ds != errSecSuccess && ds != errSecItemNotFound) {
            NSLog(@"[Tweak] bulk delete returned: %d", (int)ds);
        }

        // 3. استعادة العنصر فوراً
        restorePreservedItem(backup);
    }
}

// ==================================================================
// 8. تشغيل المؤقت تلقائياً عند بدء التطبيق
// ==================================================================

%ctor {
    if (gKeychainTimer != NULL) return;

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
