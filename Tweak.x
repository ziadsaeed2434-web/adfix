#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// 1. توليد آبي سكني أمريكي نظيف وغير مكشوف
static NSString *getResidentialFakeIP() {
    int choice = arc4random_uniform(3);
    int p3 = arc4random_uniform(250) + 1;
    int p4 = arc4random_uniform(250) + 1;
    
    if (choice == 0) {
        return [NSString stringWithFormat:@"24.%d.%d.%d", arc4random_uniform(100) + 10, p3, p4];
    } else if (choice == 1) {
        return [NSString stringWithFormat:@"32.%d.%d.%d", arc4random_uniform(100) + 50, p3, p4];
    } else {
        return [NSString stringWithFormat:@"68.%d.%d.%d", arc4random_uniform(50) + 10, p3, p4];
    }
}

// 2. IDFA ثابت طوال جلسة التطبيق (لتجنب الحظر ورفض الإعلانات)
static NSString *getSessionIDFA() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedIDFA = [defaults stringForKey:@"SMSAdSessionIDFA"];
    if (!savedIDFA) {
        savedIDFA = [[NSUUID UUID] UUIDString];
        [defaults setObject:savedIDFA forKey:@"SMSAdSessionIDFA"];
        [defaults synchronize];
    }
    return savedIDFA;
}

// 3. معرف جهاز وهمي جديد كلياً لكسر حظر الهاردوير القديم
static NSString *getBypassedVendorID() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedVendor = [defaults stringForKey:@"BypassedVendorUUID"];
    if (!savedVendor) {
        savedVendor = [[NSUUID UUID] UUIDString];
        [defaults setObject:savedVendor forKey:@"BypassedVendorUUID"];
        [defaults synchronize];
    }
    return savedVendor;
}

static CLLocationCoordinate2D getCleanFakeCoordinate() {
    double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    return CLLocationCoordinate2DMake(34.0522 + latOffset, -118.2437 + lonOffset);
}

// تصفير جلسة الآبي والـ IDFA عند فتح التطبيق لتوليد بصمة نظيفة جديدة
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"SMSAdSessionIDFA"];
        [defaults synchronize];
    }
}

// --- خطافات فك الحظر وتغيير البصمة ---

%hook UIDevice
- (NSUUID *)identifierForVendor {
    @try {
        NSString *vendorStr = getBypassedVendorID();
        return [[NSUUID alloc] initWithUUIDString:vendorStr];
    } @catch (NSException *e) {}
    return %orig;
}

- (NSString *)systemVersion {
    return @"17.5"; // إصدار نظام متوافق
}

- (NSString *)model {
    return @"iPhone";
}
%end

// تزييف الـ IDFA الإعلاني لجلسة نظيفة
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *activeIDFA = getSessionIDFA();
        if (activeIDFA) {
            return [[NSUUID alloc] initWithUUIDString:activeIDFA];
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

// تزييف الموقع الجغرافي GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getCleanFakeCoordinate();
}
%end

// --- خطافات شبكات الاتصال لحقن الآبي السكني الوهمي ---

%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *fakeIP = getResidentialFakeIP();
        
        [modifiedHeaders setObject:fakeIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:fakeIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:fakeIP forKey:@"X-Real-IP"];
        [modifiedHeaders setObject:fakeIP forKey:@"True-Client-IP"];
        
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *fakeIP = getResidentialFakeIP();
        if (field && (
            [field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
            [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame)) {
            %orig(fakeIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *fakeIP = getResidentialFakeIP();
        if (field && (
            [field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
            [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame)) {
            %orig(fakeIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setURL:(NSURL * _Nullable)url {
    %orig;
    @try {
        NSString *fakeIP = getResidentialFakeIP();
        if (url && url.absoluteString) {
            [self setValue:fakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [self setValue:fakeIP forHTTPHeaderField:@"Client-IP"];
            [self setValue:fakeIP forHTTPHeaderField:@"X-Real-IP"];
            [self setValue:fakeIP forHTTPHeaderField:@"True-Client-IP"];
        }
    } @catch (NSException *e) {}
}
%end

%hook NSURLRequest
- (NSDictionary<NSString *, NSString *> *)allHTTPHeaderFields {
    NSDictionary *origHeaders = %orig;
    NSMutableDictionary *headers = [origHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *fakeIP = getResidentialFakeIP();
    
    headers[@"X-Forwarded-For"] = fakeIP;
    headers[@"Client-IP"] = fakeIP;
    headers[@"X-Real-IP"] = fakeIP;
    headers[@"True-Client-IP"] = fakeIP;
    
    return [headers copy];
}
%end

%hook NSURLConnection
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately {
    @try {
        if ([request isKindOfClass:[NSMutableURLRequest class]]) {
            NSString *fakeIP = getResidentialFakeIP();
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"Client-IP"];
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
    return %orig(request, delegate, startImmediately);
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    @try {
        if ([request isKindOfClass:[NSMutableURLRequest class]]) {
            NSString *fakeIP = getResidentialFakeIP();
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"Client-IP"];
            [(NSMutableURLRequest *)request setValue:fakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
    return %orig(request, delegate);
}
%end
