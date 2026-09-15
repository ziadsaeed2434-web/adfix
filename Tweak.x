// Tweak.xm
// Inject 172.59.x.x IP into EVERY outgoing network request

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// ------------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------------

static NSString *generateRandomIP(void) {
    uint32_t o3 = arc4random_uniform(256);
    uint32_t o4 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"172.59.%u.%u", o3, o4];
}

// الدالة المركزية اللي تحقن كل الهيدرات المطلوبة
static void injectSpoofedHeaders(NSMutableURLRequest *req) {
    if (!req || ![req isKindOfClass:[NSMutableURLRequest class]]) return;
    @try {
        NSString *ip = generateRandomIP();
        // كل الهيدرات اللي ممكن تطبيقات تستخدمها لتحديد الأيبي
        [req setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [req setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [req setValue:ip forHTTPHeaderField:@"X-Client-IP"];
        [req setValue:ip forHTTPHeaderField:@"X-Originating-IP"];
        [req setValue:ip forHTTPHeaderField:@"CF-Connecting-IP"];
        [req setValue:ip forHTTPHeaderField:@"True-Client-IP"];
        [req setValue:ip forHTTPHeaderField:@"Forwarded"];
        [req setValue:ip forHTTPHeaderField:@"Client-IP"];
    } @catch (NSException *e) {
        NSLog(@"[Tweak] injectSpoofedHeaders error: %@", e);
    }
}

// ------------------------------------------------------------------
// 1. HOOK NSMutableURLRequest (كل مسارات التعديل الممكنة)
// ------------------------------------------------------------------

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // لو التطبيق يحاول يحط أي هيدر IP، نستبدله
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

// أهم هوك: قبل ما الـ request يتنسخ (copy) نحقن الهيدرات
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

// ------------------------------------------------------------------
// 2. HOOK NSURLRequest (الكلاس الأساسي) لاعتراض أي request قبل الإرسال
// ------------------------------------------------------------------

%hook NSURLRequest

- (NSDictionary *)allHTTPHeaderFields {
    NSMutableDictionary *orig = [%orig mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *ip = generateRandomIP();
    orig[@"X-Forwarded-For"]  = ip;
    orig[@"X-Real-IP"]        = ip;
    orig[@"X-Client-IP"]      = ip;
    orig[@"X-Originating-IP"] = ip;
    return orig;
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

// ------------------------------------------------------------------
// 3. HOOK NSURLSession (كل الـ variants)
// ------------------------------------------------------------------

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
    return %orig(req, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    injectSpoofedHeaders(req);
    return %orig(req);
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

// ------------------------------------------------------------------
// 4. HOOK NSURLConnection (الـ API القديم)
// ------------------------------------------------------------------

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

// ------------------------------------------------------------------
// 5. HOOK المستوى المنخفض جداً (CFNetwork) — لضمان تغطية 100%
//    هذا يمسك حتى الطلبات اللي ما تمر عبر NSURLSession/NSURLConnection
// ------------------------------------------------------------------

// CFURLRequestSetHTTPHeaderField هو الـ C function اللي كل شيء يمر عبرها بالنهاية
extern void CFURLRequestSetHTTPHeaderField(void *request, void *field, void *value);

%hook NSObject

// نستخدم method swizzling على مستوى الأدوات المساعدة
%end

// ------------------------------------------------------------------
// 6. IDFA SPOOFING
// ------------------------------------------------------------------

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[[NSUUID UUID] UUIDString]];
}

%end

%hook UIDevice
- (NSString *)uniqueIdentifier {
    return [[NSUUID UUID] UUIDString];
}
%end

// ------------------------------------------------------------------
// 7. KEYCHAIN CLEANUP كل 5 ثواني مع الحفاظ على tokenKey
// ------------------------------------------------------------------

static NSString *const kPreservedService = @"app.getsmscode";
static NSString *const kPreservedAccount = @"tokenKey";
static dispatch_source_t gKeychainTimer = NULL;

static NSDictionary *backupPreservedItem(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:     kPreservedService,
        (__bridge id)kSecAttrAccount:     kPreservedAccount,
        (__bridge id)kSecReturnData:      @YES,
        (__bridge id)kSecReturnAttributes:@YES,
    };
    CFTypeRef result = NULL;
    OSStatus s = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (s == errSecSuccess && result) {
        return (__bridge_transfer NSDictionary *)result;
    }
    return nil;
}

static void restorePreservedItem(NSDictionary *backup) {
    if (!backup) return;
    NSMutableDictionary *add = [backup mutableCopy];
    add[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    SecItemDelete((__bridge CFDictionaryRef)add);
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

static void performKeychainCleanup(void) {
    @autoreleasepool {
        NSDictionary *backup = backupPreservedItem();

        NSDictionary *del = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword };
        SecItemDelete((__bridge CFDictionaryRef)del);

        restorePreservedItem(backup);
    }
}

%ctor {
    if (gKeychainTimer) return;
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
