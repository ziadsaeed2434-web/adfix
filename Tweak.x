#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";

// دالة جلب أو إنشاء الهوية المرتبطة بملف التفضيلات لضمان التجديد الفعلي
static NSString *getDynamicIP() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedIP = [defaults stringForKey:@"MySpoofedIPSession"];
        
        // إذا لم يكن هناك آبي مخزن أو إذا أردنا توليد جديد
        if (!savedIP) {
            int third = arc4random_uniform(200) + 1;
            int fourth = arc4random_uniform(250) + 1;
            savedIP = [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
            [defaults setObject:savedIP forKey:@"MySpoofedIPSession"];
            [defaults synchronize];
        }
        return savedIP;
    } @catch (NSException *e) {
        return @"50.200.50.50";
    }
}

static NSString *getDynamicIDFA() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedIDFA = [defaults stringForKey:@"MySpoofedIDFASession"];
        
        if (!savedIDFA) {
            savedIDFA = [[NSUUID UUID] UUIDString];
            [defaults setObject:savedIDFA forKey:@"MySpoofedIDFASession"];
            [defaults synchronize];
        }
        return savedIDFA;
    } @catch (NSException *e) {
        return [[NSUUID UUID] UUIDString];
    }
}

// دالة تصفير الهوية عند فتح التطبيق من جديد (تُمسح القديمة لتتولد جديدة)
%ctor {
    @autoreleasepool {
        // مسح الجلسة القديمة فور بدء العملية لضمان توليد آبي و IDFA جديدين كلياً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"MySpoofedIPSession"];
        [defaults removeObjectForKey:@"MySpoofedIDFASession"];
        [defaults synchronize];
        
        // إحداثيات عشوائية طفيفة في أتلانطا
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
    }
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

// 2. إرجاع الـ IDFA الخاص بالجلسة
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *activeIDFA = getDynamicIDFA();
        if (activeIDFA) {
            return [[NSUUID alloc] initWithUUIDString:activeIDFA];
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

// 5. حقن الآبي المتجدد في إعدادات الشبكة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *activeIP = getDynamicIP();
        
        if (activeIP) {
            [modifiedHeaders setObject:activeIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:activeIP forKey:@"Client-IP"];
            [modifiedHeaders setObject:activeIP forKey:@"X-Real-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

// 6. حقن الآبي المتجدد في الطلبات الصادرة
%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *activeIP = getDynamicIP();
        if (field && activeIP && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(activeIP, field);
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
        NSString *activeIP = getDynamicIP();
        if (url && url.absoluteString && activeIP) {
            [self setValue:activeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [self setValue:activeIP forHTTPHeaderField:@"Client-IP"];
            [self setValue:activeIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
}
%end
