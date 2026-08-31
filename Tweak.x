#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <objc/runtime.h>

// إحداثيات أتلانتا، جورجيا، أمريكا (Atlanta, Georgia, USA)
static double kFakeLatitude = 33.7490;
static double kFakeLongitude = -84.3880;

// متغيرات البصمة والـ IP المتغيرة لكل جلسة فتح للتطبيق
static NSString *currentRandomIDFA = nil;
static NSString *currentVendorID = nil;
static NSString *currentMockIP = nil;

// دالة توليد بصمة جديدة و IP أمريكي جديد نظيف
void rotateIPAndFingerprint() {
    currentRandomIDFA = [[NSUUID UUID] UUIDString];
    currentVendorID = [[NSUUID UUID] UUIDString];
    
    int thirdOctet = arc4random_uniform(20) + 10;
    int fourthOctet = arc4random_uniform(250) + 2;
    currentMockIP = [NSString stringWithFormat:@"12.186.%d.%d", thirdOctet, fourthOctet];
    
    NSLog(@"[GeoIP] Rotated -> IDFA: %@ | Mock IP: %@", currentRandomIDFA, currentMockIP);
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
// 2. تزييف معرفات الأجهزة (IDFA & IDFV)
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
// 3. حقن الـ IP المزود في كل طلب شبكي (NSURLSession)
// ==========================================
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (mutableReq && currentMockIP) {
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Client-IP"];
    }
    return %orig(mutableReq ? mutableReq : request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (mutableReq && currentMockIP) {
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:currentMockIP forHTTPHeaderField:@"X-Client-IP"];
    }
    return %orig(mutableReq ? mutableReq : request);
}

%end

// ==========================================
// 4. تغيير الـ IP والبصمة مع كل فتحة جديدة للتطبيق
// ==========================================
%ctor {
    // تدوير الـ IP والبصمة عند فتح التطبيق أول مرة
    rotateIPAndFingerprint();
    
    // تدوير الـ IP والبصمة تلقائياً في كل مرة تخرج من التطبيق وتعود إليه (Foreground)
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        rotateIPAndFingerprint();
        NSLog(@"[GeoIP] App resumed. New IP and location parameters applied!");
    }];
}
