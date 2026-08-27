#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";

// دالة لتوليد آبي جديد كلياً
static NSString *generateRandomIP() {
    @try {
        int third = arc4random_uniform(200) + 1;
        int fourth = arc4random_uniform(250) + 1;
        return [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
    } @catch (NSException *e) {
        return @"50.200.25.75";
    }
}

// دالة لتوليد IDFA جديد كلياً
static NSString *generateRandomIDFA() {
    @try {
        return [[NSUUID UUID] UUIDString];
    } @catch (NSException *e) {
        return @"00000000-0000-0000-0000-000000000000";
    }
}

%ctor {
    // تحديث الإحداثيات العشوائية في أتلانطا عند البداية
    double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    sessionLatitude = 33.7490 + latOffset;
    sessionLongitude = -84.3880 + lonOffset;
}

// 1. تزييف لغة النظام بأمان
%hook NSLocale
+ (NSArray<NSString *> *)preferredLanguages {
    return @[@"en-US", @"en"];
}
- (NSString *)countryCode {
    return @"US";
}
%end

// 2. إرجاع IDFA جديد مختلف مع كل استعلام
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *newIDFA = generateRandomIDFA();
        if (newIDFA) {
            return [[NSUUID alloc] initWithUUIDString:newIDFA];
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

// 5. حقن آبي جديد مع كل إعدادات جلسة شبكية
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *dynamicIP = generateRandomIP();
        if (dynamicIP) {
            [modifiedHeaders setObject:dynamicIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:dynamicIP forKey:@"Client-IP"];
            [modifiedHeaders setObject:dynamicIP forKey:@"X-Real-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

// 6. حقن آبي جديد ومختلف مع *كل طلب شبكي فردي* يرسله التطبيق
%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    @try {
        NSString *dynamicIP = generateRandomIP();
        if (field && dynamicIP && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(dynamicIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setURL:(NSURL *)url {
    %orig;
    @try {
        NSString *dynamicIP = generateRandomIP();
        if (url && url.absoluteString && dynamicIP) {
            [self setValue:dynamicIP forHTTPHeaderField:@"X-Forwarded-For"];
            [self setValue:dynamicIP forHTTPHeaderField:@"Client-IP"];
            [self setValue:dynamicIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
}
%end
