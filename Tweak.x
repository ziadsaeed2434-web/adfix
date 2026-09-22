#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

static NSString *currentActiveIP = nil;
static double currentLatitude = 0.0;
static double currentLongitude = 0.0;

// قائمة أفضل النطاقات السكنية الحقيقية في بريطانيا (UK Residential ISPs) لجلب وقبول الإعلانات
static NSArray *getUKResidentialIPPool() {
    return @[
        // BT (British Telecom) Residential
        @"86.130", @"86.140", @"81.150", @"82.163",
        // Sky Broadband Residential
        @"90.200", @"90.201", @"94.197", @"2.120",
        // Virgin Media Residential
        @"82.132", @"82.40", @"86.15", @"80.2.1",
        // TalkTalk Residential
        @"62.252", @"78.144", @"92.23", @"91.84"
    ];
}

// توليد IP بريطاني سكني حقيقي
static NSString *randomUKResidentialIP() {
    NSArray *pool = getUKResidentialIPPool();
    NSString *prefix = pool[arc4random_uniform((uint32_t)[pool count])];
    
    int part3 = arc4random_uniform(250) + 1;
    int part4 = arc4random_uniform(250) + 1;
    
    return [NSString stringWithFormat:@"%@.%d.%d", prefix, part3, part4];
}

// توليد إحداثيات جغرافية دقيقة ومتطابقة مع بريطانيا (حول لندن)
static void generateUKMatchedCoordinates(double *lat, double *lon) {
    *lat = 51.5074 + ((double)(arc4random_uniform(150) - 75) / 100.0);
    *lon = -0.1278 + ((double)(arc4random_uniform(150) - 75) / 100.0);
}

// دالة لتنظيف كاش الشبكة بالكامل
static void clearNetworkCache() {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
}

// تحديث الـ IP، الموقع، وحذف الكاش بالكامل كل دقيقة (60 ثانية)
static void updateUKIPLocationAndCache() {
    @autoreleasepool {
        // 1. تفريغ كاش الشبكة
        clearNetworkCache();
        
        // 2. توليد IP بريطاني سكني جديد
        currentActiveIP = randomUKResidentialIP();
        
        // 3. توليد إحداثيات بريطانية متطابقة
        generateUKMatchedCoordinates(&currentLatitude, &currentLongitude);
        
        NSLog(@">>> [UK-Residential-Ads] New IP: %@ | Location: %f, %f | Cache Wiped", currentActiveIP, currentLatitude, currentLongitude);
    }
}

// تشغيل التحديث فوراً وكل دقيقة (60.0 ثانية) في الخلفية
static __attribute__((constructor)) void initialUKSetup() {
    updateUKIPLocationAndCache();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:60.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            updateUKIPLocationAndCache();
        }];
    });
}

// حقن الـ IP البريطاني السكني في ترويسات الطلبات (Headers)
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        if (!currentActiveIP) {
            currentActiveIP = randomUKResidentialIP();
        }
        value = currentActiveIP;
    }
    %orig(value, field);
}
%end

// مطابقة موقع الـ GPS مع الموقع البريطاني الجديد
%hook CLLocationManager

- (CLLocation *)location {
    if (currentLatitude == 0.0 && currentLongitude == 0.0) {
        generateUKMatchedCoordinates(&currentLatitude, &currentLongitude);
    }
    return [[CLLocation alloc] initWithLatitude:currentLatitude longitude:currentLongitude];
}

- (void)startUpdatingLocation {
    %orig;
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLatitude longitude:currentLongitude];
        [[self delegate] locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}

%end
