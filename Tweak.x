#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// 1. توليد آبي أمريكي عشوائي جديد كلياً وطائر مع كل طلب
static NSString *getRandomIP() {
    int third = arc4random_uniform(200) + 1;
    int fourth = arc4random_uniform(250) + 1;
    return [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
}

// 2. توليد IDFA جديد كلياً وطائر عند الطلب
static NSString *getRandomIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// 3. إحداثيات عشوائية طفيفة ومتحركة مع كل طلب
static CLLocationCoordinate2D getRandomCoordinate() {
    double baseLat = 33.7490;
    double baseLon = -84.3880;
    double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    return CLLocationCoordinate2DMake(baseLat + latOffset, baseLon + lonOffset);
}

// تزييف الـ IDFA فوراً عند طلبه
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *newIDFA = getRandomIDFA();
        if (newIDFA) {
            return [[NSUUID alloc] initWithUUIDString:newIDFA];
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

// تزييف الموقع الجغرافي ليتطابق دائماً
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getRandomCoordinate();
}
%end

// 1. حقن الآبي الجديد في إعدادات جلسات الشبكة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *newIP = getRandomIP();
        if (newIP) {
            [modifiedHeaders setObject:newIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:newIP forKey:@"Client-IP"];
            [modifiedHeaders setObject:newIP forKey:@"X-Real-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

// 2. حقن الآبي الجديد في الطلبات القابلة للتعديل
%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *newIP = getRandomIP();
        if (field && newIP && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(newIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *newIP = getRandomIP();
        if (field && newIP && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(newIP, field);
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
        NSString *newIP = getRandomIP();
        if (url && url.absoluteString && newIP) {
            [self setValue:newIP forHTTPHeaderField:@"X-Forwarded-For"];
            [self setValue:newIP forHTTPHeaderField:@"Client-IP"];
            [self setValue:newIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
}
%end

// 3. ضمان شمول الطلبات العادية عبر التقاط Tweak لـ NSURLRequest بأمان
%hook NSURLRequest
- (NSDictionary<NSString *, NSString *> *)allHTTPHeaderFields {
    NSDictionary *origHeaders = %orig;
    NSMutableDictionary *headers = [origHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *newIP = getRandomIP();
    if (newIP) {
        headers[@"X-Forwarded-For"] = newIP;
        headers[@"Client-IP"] = newIP;
        headers[@"X-Real-IP"] = newIP;
    }
    return [headers copy];
}
%end
