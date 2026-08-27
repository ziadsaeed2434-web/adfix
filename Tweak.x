#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";

// متغيرات لتخزين الهوية الحالية وتحديثها بشكل دوري
static NSString *currentForcedIP = nil;
static NSString *currentForcedIDFA = nil;

// دالة لتوليد آبي جديد تماماً
static NSString *getNewIP() {
    int third = arc4random_uniform(200) + 1;
    int fourth = arc4random_uniform(250) + 1;
    return [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
}

// دالة لتوليد IDFA جديد تماماً
static NSString *getNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// دالة إجبار تحديث الهوية فوراً
static void forceRotateIdentity() {
    @try {
        currentForcedIP = getNewIP();
        currentForcedIDFA = getNewIDFA();
        
        // مسح الكاش الشبكي تماماً لمنع الحفظ المؤقت
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // عشوائية خفيفة لموقع أتلانطا
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
    } @catch (NSException *e) {}
}

%ctor {
    forceRotateIdentity();
}

// 1. تزييف لغة النظام
%hook NSLocale
+ (NSArray<NSString *> *)preferredLanguages {
    return @[@"en-US", @"en"];
}
- (NSString *)countryCode {
    return @"US";
}
%end

// 2. إرجاع IDFA متجدد وإجباري مع كل استعلام
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        // تحديث الهوية فوراً عند كل طلب IDFA
        forceRotateIdentity();
        if (currentForcedIDFA) {
            return [[NSUUID alloc] initWithUUIDString:currentForcedIDFA];
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

// 3. مطابقة التوقيت الزمني
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
+ (NSTimeZone *)systemTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
%end

// 4. مطابقة الـ GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 5. إجبار تغيير الآبي وحقنه مع كل تكوين شبكي جديد
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        forceRotateIdentity(); // تغيير إجباري للآبي
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        if (currentForcedIP) {
            [modifiedHeaders setObject:currentForcedIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:currentForcedIP forKey:@"Client-IP"];
            [modifiedHeaders setObject:currentForcedIP forKey:@"X-Real-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

// 6. إجبار تغيير وحقن الآبي مع كل طلب شبكي فردي صادر
%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        if (field && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            forceRotateIdentity(); // تغيير إجباري
            if (currentForcedIP) {
                %orig(currentForcedIP, field);
                return;
            }
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setURL:(NSURL * _Nullable)url {
    %orig;
    @try {
        if (url && url.absoluteString) {
            forceRotateIdentity(); // تغيير إجباري مع كل رابط جديد
            if (currentForcedIP) {
                [self setValue:currentForcedIP forHTTPHeaderField:@"X-Forwarded-For"];
                [self setValue:currentForcedIP forHTTPHeaderField:@"Client-IP"];
                [self setValue:currentForcedIP forHTTPHeaderField:@"X-Real-IP"];
            }
        }
    } @catch (NSException *e) {}
}
%end
