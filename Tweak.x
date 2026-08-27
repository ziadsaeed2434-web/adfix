#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

// إحداثيات هولندا - زوترمير (مطابقة تماماً للـ IP)
static double sessionLatitude = 52.0575;
static double sessionLongitude = 4.49306;
static NSString *targetFixedIP = @"87.212.61.114"; 
static NSString *sessionTimeZoneName = @"Europe/Amsterdam";

// 1. مطابقة التوقيت الزمني لهولندا بأمان تام
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    if (sessionTimeZoneName) {
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:sessionTimeZoneName];
        if (tz) return tz;
    }
    return %orig;
}
+ (NSTimeZone *)systemTimeZone {
    if (sessionTimeZoneName) {
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:sessionTimeZoneName];
        if (tz) return tz;
    }
    return %orig;
}
%end

// 2. مطابقة موقع الـ GPS ليكون في هولندا (زوترمير)
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 3. فرض إرسال الآبي الثابت في ترويسات الشبكة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy];
    if (!modifiedHeaders) {
        modifiedHeaders = [NSMutableDictionary dictionary];
    }
    if (targetFixedIP) {
        [modifiedHeaders setObject:targetFixedIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:targetFixedIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:targetFixedIP forKey:@"X-Real-IP"];
    }
    %orig(modifiedHeaders);
}
%end

// 4. حقن الآبي الثابت في كافة الطلبات الصادرة بدون كراش
%hook NSMutableURLRequest

- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    if (field && targetFixedIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(targetFixedIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && targetFixedIP) {
        [self setValue:targetFixedIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:targetFixedIP forHTTPHeaderField:@"Client-IP"];
    }
}

%end
