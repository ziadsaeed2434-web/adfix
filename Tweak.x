#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <objc/runtime.h>

// إحداثيات أتلانتا، جورجيا، أمريكا (Atlanta, Georgia, USA)
static double kFakeLatitude = 33.7490;
static double kFakeLongitude = -84.3880;

// متغيرات لتخزين البصمة الرقمية المتغيرة لكل جلسة
static NSString *currentRandomIDFA = nil;
static NSString *currentVendorID = nil;
static NSString *currentMockIP = nil;

// دالة لتوليد هوية جديدة وعنوان IP أمريكي وهمي ونظيف لكل طلب أو جلسة
void randomizeDeviceFingerprintAndIP() {
    // 1. توليد IDFA و IDFV عشوائي جديد تماماً
    currentRandomIDFA = [[NSUUID UUID] UUIDString];
    currentVendorID = [[NSUUID UUID] UUIDString];
    
    // 2. توليد نطاق IP أمريكي عشوائي ونظيف (مثلاً في نطاق ولاية جورجيا / أتلانتا)
    int thirdOctet = arc4random_uniform(20) + 10;   // نطاق عشوائي نظيف
    int fourthOctet = arc4random_uniform(250) + 2;
    currentMockIP = [NSString stringWithFormat:@"12.186.%d.%d", thirdOctet, fourthOctet];
    
    NSLog(@"[Anti-GeoBlock] Rotated Fingerprint -> IDFA: %@ | Mock IP: %@", currentRandomIDFA, currentMockIP);
}

// ==========================================
// 1. تزييف الموقع الجغرافي (Location Spoofing)
// ==========================================
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(kFakeLatitude, kFakeLongitude);
}

- (CLLocationAccuracy)horizontalAccuracy {
    return 5.0;
}

- (CLLocationAccuracy)verticalAccuracy {
    return 5.0;
}

%end

%hook CLLocationManager

- (CLLocation *)location {
    return [[CLLocation alloc] initWithLatitude:kFakeLatitude longitude:kFakeLongitude];
}

- (void)startUpdatingLocation {
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *fakeLoc = [[CLLocation alloc] initWithLatitude:kFakeLatitude longitude:kFakeLongitude];
        [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
    }
}

%end

// ==========================================
// 2. تزييف معرفات الأجهزة والملفات (IDFA & Device)
// ==========================================
%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:currentRandomIDFA ?: [[NSUUID UUID] UUIDString]];
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentVendorID ?: [[NSUUID UUID] UUIDString]];
}

- (NSString *)systemName {
    return @"iOS";
}

%end

// ==========================================
// 3. حقن الـ IP المزود ونطاقات الطلبات (Network Hooking)
// ==========================================
%hook NSMutableURLRequest

- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)fields {
    NSMutableDictionary *newFields = [fields mutableCopy];
    if (!newFields) {
        newFields = [NSMutableDictionary dictionary];
    }
    
    // حقن رأس ترويسي يحاكي الـ IP الأمريكي الوهمي والنظيف في كل طلب شبكي
    if (currentMockIP) {
        [newFields setObject:currentMockIP forKey:@"X-Forwarded-For"];
        [newFields setObject:currentMockIP forKey:@"X-Client-IP"];
        [newFields setObject:currentMockIP forKey:@"Client-IP"];
    }
    
    %orig(newFields);
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame && currentMockIP) {
        value = currentMockIP;
    }
    %orig(value, field);
}

%end

// اعتراض NSURLSession وتحديث الـ Headers لكل طلب يتم إنشاؤه
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    if (currentMockIP) {
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Client-IP"];
    }
    
    return %orig(mutableReq, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    if (currentMockIP) {
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Client-IP"];
    }
    
    return %orig(mutableReq);
}

%end

// ==========================================
// 4. مراقبة تفعيل التطبيق وتدوير الهوية تلقائياً
// ==========================================
%ctor {
    // توليد بصمة و IP أولي عند الحقن
    randomizeDeviceFingerprintAndIP();
    
    // رصد العودة للتطبيق (Foreground) لتغيير البصمة والـ IP الوهمي فوراً
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        randomizeDeviceFingerprintAndIP();
        NSLog(@"[Anti-GeoBlock] App resumed. Fingerprint and IP rotated completely!");
    }];
}
