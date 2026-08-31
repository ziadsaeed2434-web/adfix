#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <objc/runtime.h>
#import <Security/Security.h>

// إحداثيات أتلانتا، جورجيا، أمريكا (Atlanta, Georgia, USA)
static double kFakeLatitude = 33.7490;
static double kFakeLongitude = -84.3880;

// متغيرات البصمة والمتغيرات العشوائية الجديدة لكل جلسة
static NSString *currentRandomIDFA = nil;
static NSString *currentVendorID = nil;
static NSString *currentGlobalUUID = nil;
static NSString *currentMockIP = nil;

// دالة تفريغ وحذف بيانات الجلسة وتوليد UUID جديد كلياً
void wipeAppSessionData() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // 1. مسح الـ NSUserDefaults بالكامل
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 2. مسح ملفات Caches المؤقتة
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths firstObject];
    if (cacheDirectory) {
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cacheDirectory error:&error];
        for (NSString *file in contents) {
            NSString *fullPath = [cacheDirectory stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
        }
    }
    
    // 3. مسح الـ Keychain بالكامل عدا العناصر المستثناة (userIDKey & accessTokenKey)
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword
    };
    
    CFArrayRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess && result) {
        NSArray *items = (__bridge_transfer NSArray *)result;
        for (NSDictionary *item in items) {
            NSString *service = item[(__bridge id)kSecAttrService];
            NSString *account = item[(__bridge id)kSecAttrAccount];
            
            BOOL isExcepted = ([service isEqualToString:@"com.codebysms"] && 
                               ([account isEqualToString:@"userIDKey"] || [account isEqualToString:@"accessTokenKey"]));
            
            if (!isExcepted) {
                NSDictionary *delQuery = @{
                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                    (__bridge id)kSecAttrService: service ?: @"",
                    (__bridge id)kSecAttrAccount: account ?: @""
                };
                SecItemDelete((__bridge CFDictionaryRef)delQuery);
            }
        }
    }
    
    // 4. توليد هويات جهاز جديدة بالكامل (بما فيها UUID عالمي جديد)
    currentRandomIDFA = [[NSUUID UUID] UUIDString];
    currentVendorID = [[NSUUID UUID] UUIDString];
    currentGlobalUUID = [[NSUUID UUID] UUIDString];
    
    // 5. توليد IP أمريكي جديد في أتلانتا
    int thirdOctet = arc4random_uniform(20) + 10;
    int fourthOctet = arc4random_uniform(250) + 2;
    currentMockIP = [NSString stringWithFormat:@"12.186.%d.%d", thirdOctet, fourthOctet];
    
    NSLog(@"[CleanSlate] Full wipe & UUID rotated. New UUID: %@ | IP: %@", currentGlobalUUID, currentMockIP);
    
    [pool drain];
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
// 2. تزييف معرفات الأجهزة والـ UUID
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

// اعتراض دوال إنشاط الـ NSUUID لمنح التطبيق UUID متجدد بالكامل
%hook NSUUID

- (instancetype)initWithUUIDString:(NSString *)string {
    if (currentGlobalUUID) {
        return %orig(currentGlobalUUID);
    }
    return %orig;
}

+ (id)UUID {
    if (currentGlobalUUID) {
        return [[NSUUID alloc] initWithUUIDString:currentGlobalUUID];
    }
    return %orig;
}

%end

// ==========================================
// 3. حقن الـ IP عبر NSURLSession بأمان تام
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
// 4. تدوير الهوية ومسح البيانات عند فتح وإغلاق التطبيق
// ==========================================
%ctor {
    wipeAppSessionData();
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        wipeAppSessionData();
        NSLog(@"[CleanSlate] App resumed. New UUID and clean environment applied.");
    }];
}
