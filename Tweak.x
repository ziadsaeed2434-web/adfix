#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// توليد آبي سكني أمريكي متجدد
static NSString *getDynamicResidentialIP() {
    int choice = arc4random_uniform(3);
    int p3 = arc4random_uniform(250) + 1;
    int p4 = arc4random_uniform(250) + 1;
    if (choice == 0) return [NSString stringWithFormat:@"24.%d.%d.%d", arc4random_uniform(100) + 10, p3, p4];
    if (choice == 1) return [NSString stringWithFormat:@"32.%d.%d.%d", arc4random_uniform(100) + 50, p3, p4];
    return [NSString stringWithFormat:@"68.%d.%d.%d", arc4random_uniform(50) + 10, p3, p4];
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

// 1. تزييف الوقت (إبداء أن الوقت قد تقدم بعدة ساعات أو أيام لكسر الانتظار)
%hook NSDate

+ (NSDate *)date {
    NSDate *realDate = %orig;
    // تقديم الوقت بـ 4 ساعات مثلاً (يمكنك تعديل الثواني بحسب الحاجة: 3600 ثانية = ساعة)
    return [realDate dateByAddingTimeInterval:14400.0]; 
}

- (instancetype)initWithTimeIntervalSinceNow:(NSTimeInterval)secs {
    // تقديم أي عداد زمني يعتمد على الفترات القادمة
    return %orig(secs + 14400.0);
}

%end

// 2. بصمة جهاز جديدة ومتجددة
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

// 3. معرف إعلاني جديد كلياً
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

// 4. الموقع الجغرافي المتحرك
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getRandomUSCoordinate();
}
%end

// 5. حقن الآبي السكني المتجدد في الترويسات
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *fakeIP = getDynamicResidentialIP();
        
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
- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *fakeIP = getDynamicResidentialIP();
        if (field && (
            [field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
            [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
            [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(fakeIP, field);
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
    NSString *fakeIP = getDynamicResidentialIP();
    
    headers[@"X-Forwarded-For"] = fakeIP;
    headers[@"Client-IP"] = fakeIP;
    headers[@"X-Real-IP"] = fakeIP;
    
    return [headers copy];
}
%end
