#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

static double currentLat = 0.0;
static double currentLon = 0.0;

// توليد رقم عشوائي آمن
double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

// توليد إحداثيات عشوائية جديدة داخل مدينة أتلانطا، أمريكا
void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// تهيئة الموقع فور فتح التطبيق
%ctor {
    updateAtlantaLocation();
}

// 1. خداع نظام تحديد الموقع (GPS) وتوجيهه لإحداثيات أتلانطا الوهمية
%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}

- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

// 2. خداع المنطقة الزمنية لتوقيت أمريكا
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    NSTimeZone *atlantaTZ = [NSTimeZone timeZoneWithName:@"America/New_York"];
    return atlantaTZ ? atlantaTZ : %orig;
}

+ (NSTimeZone *)systemTimeZone {
    NSTimeZone *atlantaTZ = [NSTimeZone timeZoneWithName:@"America/New_York"];
    return atlantaTZ ? atlantaTZ : %orig;
}
%end

// 3. خداع لغة ومنطقة الجهاز لتكون الولايات المتحدة (en_US)
%hook NSLocale
+ (NSLocale *)currentLocale {
    return [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
}

+ (id)autoupdatingCurrentLocale {
    return [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
}
%end

// 4. خداع معلومات الشبكة والشريحة لتظهر كأنها شبكة أمريكية (Carrier)
%hook CTCarrier
- (NSString *)carrierName {
    return @"AT&T"; // اسم شركة اتصالات أمريكية مشهورة
}

- (NSString *)mobileCountryCode {
    return @"310"; // رمز الدولة (MCC) للولايات المتحدة
}

- (NSString *)mobileNetworkCode {
    return @"410"; // رمز المزود (MNC) لأمريكا
}

- (NSString *)isoCountryCode {
    return @"us"; // رمز الدولة ISO
}

- (BOOL)allowsVOIP {
    return YES;
}
%end
