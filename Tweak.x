#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// توليد آلاف الآبيات السكنية الحقيقية والنظيفة ديناميكياً من النطاقات الفعلية للشركات الأمريكية
static NSString *generateMassiveRealResidentialIP() {
    // مصفوفة تحتوي على بادئات النطاقات الحقيقية (ASN Prefix) لأكبر مزودي إنترنت منزلي ومحمول
    NSArray *ispPrefixes = @[
        @"[24.180]",  // Comcast Residential
        @"[24.184]",  // Comcast Cable
        @"[32.211]",  // AT&T Fiber
        @"[32.215]",  // AT&T U-verse
        @"[68.192]",  // Verizon Fios
        @"[68.198]",  // Verizon Broadband
        @"[71.34]",   // Spectrum Internet
        @"[71.40]",   // Charter Communications
        @"[172.56]",  // T-Mobile Mobile Home ISP
        @"[63.231]"   // CenturyLink DSL/Fiber
    ];
    
    // اختيار مزود عشوائي
    int ispIndex = arc4random_uniform((uint32_t)[ispPrefixes count]);
    
    // توليد الأجزاء الباقية بشكل عشوائي داخل النطاق الصحيح (يعطي آلاف الاحتمالات الحقيقية والنظيفة)
    int p3 = arc4random_uniform(254) + 1;
    int p4 = arc4random_uniform(254) + 1;
    
    if (ispIndex == 0) return [NSString stringWithFormat:@"24.180.%d.%d", p3, p4];
    if (ispIndex == 1) return [NSString stringWithFormat:@"24.184.%d.%d", p3, p4];
    if (ispIndex == 2) return [NSString stringWithFormat:@"32.211.%d.%d", p3, p4];
    if (ispIndex == 3) return [NSString stringWithFormat:@"32.215.%d.%d", p3, p4];
    if (ispIndex == 4) return [NSString stringWithFormat:@"68.192.%d.%d", p3, p4];
    if (ispIndex == 5) return [NSString stringWithFormat:@"68.198.%d.%d", p3, p4];
    if (ispIndex == 6) return [NSString stringWithFormat:@"71.34.%d.%d", p3, p4];
    if (ispIndex == 7) return [NSString stringWithFormat:@"71.40.%d.%d", p3, p4];
    if (ispIndex == 8) return [NSString stringWithFormat:@"172.56.%d.%d", p3, p4];
    
    return [NSString stringWithFormat:@"63.231.%d.%d", p3, p4];
}

static NSString *getFreshUUID(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *newID = [[NSUUID UUID] UUIDString];
    [defaults setObject:newID forKey:key];
    [defaults synchronize];
    return newID;
}

static CLLocationCoordinate2D getRandomUSCoordinate() {
    double latOffset = ((arc4random_uniform(400) - 200) / 10000.0);
    double lonOffset = ((arc4random_uniform(400) - 200) / 10000.0);
    return CLLocationCoordinate2DMake(34.0522 + latOffset, -118.2437 + lonOffset);
}

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"ActiveAdSessionIDFA"];
        [defaults removeObjectForKey:@"ActiveVendorID"];
        [defaults synchronize];
    }
}

// 1. تزييف الوقت (تقديم الوقت 4 ساعات لتجاوز فترات الحظر المؤقت)
%hook NSDate
+ (NSDate *)date {
    NSDate *realDate = %orig;
    return [realDate dateByAddingTimeInterval:14400.0];
}
- (instancetype)initWithTimeIntervalSinceNow:(NSTimeInterval)secs {
    return %orig(secs + 14400.0);
}
%end

// 2. تجديد بصمة الجهاز
%hook UIDevice
- (NSUUID *)identifierForVendor {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *vID = [defaults stringForKey:@"ActiveVendorID"];
        if (!vID) {
            vID = getFreshUUID(@"ActiveVendorID");
        }
        return [[NSUUID alloc] initWithUUIDString:vID];
    } @catch (NSException *e) {}
    return %orig;
}

- (NSString *)systemVersion {
    return @"17.5";
}
%end

// 3. تجديد معرف الإعلانات
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *idfa = [defaults stringForKey:@"ActiveAdSessionIDFA"];
        if (!idfa) {
            idfa = getFreshUUID(@"ActiveAdSessionIDFA");
        }
        return [[NSUUID alloc] initWithUUIDString:idfa];
    } @catch (NSException *e) {}
    return %orig;
}
%end

// 4. تزييف الموقع الجغرافي
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getRandomUSCoordinate();
}
%end

// 5. حقن الآبيات الديناميكية الحقيقية في ترويسات الشبكة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *realIP = generateMassiveRealResidentialIP();
        
        [modifiedHeaders setObject:realIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:realIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:realIP forKey:@"X-Real-IP"];
        [modifiedHeaders setObject:realIP forKey:@"True-Client-IP"];
        
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *realIP = generateMassiveRealResidentialIP();
        if (field && (
            [field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
            [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(realIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}
%end

%hook NSURLRequest
- (NSDictionary<NSString *, NSString *> *)allHTTPHeaderFields {
    NSDictionary *origHeaders = %orig;
    NSMutableDictionary *headers = [origHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *realIP = generateMassiveRealResidentialIP();
    
    headers[@"X-Forwarded-For"] = realIP;
    headers[@"Client-IP"] = realIP;
    headers[@"X-Real-IP"] = realIP;
    
    return [headers copy];
}
%end
