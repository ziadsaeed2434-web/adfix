#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

static NSString *currentActiveIP = nil;
static double currentLatitude = 0.0;
static double currentLongitude = 0.0;

// قائمة بنطاقات مزودي الخدمة السكنيين الحقيقيين في أوروبا (Residential ISPs) لضمان قبول الإعلانات
static NSArray *getResidentialIPPool() {
    return @[
        // ألمانيا - Deutsche Telekom / Vodafone (Residential)
        @"87.138", @"91.64", @"188.100", @"79.200",
        // فرنسا - Orange / Free / SFR (Residential)
        @"80.12", @"90.109", @"78.119", @"88.160",
        // بريطانيا - BT / Sky / Virgin Media (Residential)
        @"86.130", @"90.200", @"82.132", @"78.144"
    ];
}

// دالة لتوليد IP سكني حقيقي ومضمون للإعلانات
static NSString *randomResidentialEuropeanIP() {
    NSArray *pool = getResidentialIPPool();
    NSString *prefix = pool[arc4random_uniform((uint32_t)[pool count])];
    
    int part3 = arc4random_uniform(250) + 1;
    int part4 = arc4random_uniform(250) + 1;
    
    return [NSString stringWithFormat:@"%@.%d.%d", prefix, part3, part4];
}

// دالة لتوليد إحداثيات جغرافية دقيقة ومتطابقة مع أوروبا
static void generateMatchedCoordinates(double *lat, double *lon) {
    // إحداثيات واقعية في أوروبا (مناطق وسط أوروبا)
    *lat = 48.8566 + ((double)(arc4random_uniform(200) - 100) / 100.0); // حول باريس/ألمانيا
    *lon = 2.3522 + ((double)(arc4random_uniform(200) - 100) / 100.0);
}

// تحديث الـ IP السكني والموقع كل 10 ثوانٍ
static void updateResidentialIPAndLocation() {
    currentActiveIP = randomResidentialEuropeanIP();
    generateMatchedCoordinates(&currentLatitude, &currentLongitude);
    
    NSLog(@">>> [Residential-Ads-Ready] New Residential IP: %@ | Location: %f, %f", currentActiveIP, currentLatitude, currentLongitude);
}

// تشغيل التحديث فوراً وكل 10 ثوانٍ
static __attribute__((constructor)) void initialResidentialSetup() {
    updateResidentialIPAndLocation();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:10.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            updateResidentialIPAndLocation();
        }];
    });
}

// حقن الـ IP السكني في الترويسات للطلبات المرسلة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        if (!currentActiveIP) {
            currentActiveIP = randomResidentialEuropeanIP();
        }
        value = currentActiveIP;
    }
    %orig(value, field);
}
%end

// مطابقة موقع الـ GPS مع الـ IP السكني الجديد
%hook CLLocationManager

- (CLLocation *)location {
    if (currentLatitude == 0.0 && currentLongitude == 0.0) {
        generateMatchedCoordinates(&currentLatitude, &currentLongitude);
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
