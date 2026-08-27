#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// توليد آبي من نطاقات سكنية ومحمولة أمريكية حقيقية (Residential / Mobile Carrier) غير مكشوفة
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

static NSString *getCleanFakeIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static CLLocationCoordinate2D getCleanFakeCoordinate() {
    double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    return CLLocationCoordinate2DMake(34.0522 + latOffset, -118.2437 + lonOffset);
}

// 1. تزييف الـ IDFA الإعلاني
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *fakeIDFA = getCleanFakeIDFA();
        if (fakeIDFA) {
            return [[NSUUID alloc] initWithUUIDString:fakeIDFA];
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

// 2. تزييف الموقع الجغرافي GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getCleanFakeCoordinate();
}
%end

// 3. حقن الآبي في إعدادات جلسات الشبكة الحديثة
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

// 4. حقن الآبي في الطلبات القابلة للتعديل
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

// 5. تعديل الطلبات العادية NSURLRequest
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

// 6. تغطية وحقن الآبي في اتصالات NSURLConnection القديمة
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
