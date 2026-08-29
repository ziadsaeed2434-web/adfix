#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *rotatingIDFA = nil;
static NSString *rotatingUUID = nil;
static NSString *rotatingMAC = nil;
static NSString *randomLocale = nil;
static NSString *randomTimeZone = nil;
static NSString *randomSystemVersion = nil;
static float randomBattery = 0.5f;
static CGFloat randomScale = 2.0f;

static void generateUltimateFingerprintPersona() {
    // 1. المعرفات تتجدد
    rotatingIDFA = [[NSUUID UUID] UUIDString];
    rotatingUUID = [[NSUUID UUID] UUIDString];
    
    // 2. توليد ماك أدرس عشوائي ومزيف بصيغة صحيحة لكل إقلاع
    rotatingMAC = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256),
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
    
    // 3. لغة ونطاق عشوائي
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"en_AU"];
    randomLocale = locales[arc4random_uniform((uint32_t)locales.count)];
    
    // 4. منطقة زمنية عشوائية
    NSArray *timeZones = @[@"America/New_York", @"America/Chicago", @"America/Los_Angeles", @"Europe/London"];
    randomTimeZone = timeZones[arc4random_uniform((uint32_t)timeZones.count)];
    
    // 5. إصدارات نظام مختلفة
    NSArray *versions = @[@"17.4", @"17.5", @"18.0", @"18.1", @"26.6"];
    randomSystemVersion = versions[arc4random_uniform((uint32_t)versions.count)];
    
    // 6. نسبة بطارية وعرض عشوائية
    randomBattery = (float)(arc4random_uniform(85) + 10) / 100.0f;
    NSArray *scales = @[@2.0f, @3.0f];
    randomScale = [scales[arc4random_uniform((uint32_t)scales.count)] floatValue];
}

@interface UltimateFingerprintHUD : NSObject
+ (void)showStatus;
@end

@implementation UltimateFingerprintHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 310, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:0.4 alpha:0.95];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"🔒 Safe Fingerprint Spoofer Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    generateUltimateFingerprintPersona();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UltimateFingerprintHUD showStatus];
    });
}

// 1. معرفات الإعلانات والـ UUID المتجددة
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:rotatingIDFA];
}
%end

%hook NSUUID
- (instancetype)initWithUUIDString:(NSString *)string {
    return %orig(rotatingUUID);
}
%end

// 2. إصدار النظام والبطارية الآمنة
%hook UIDevice
- (NSString *)systemVersion {
    return randomSystemVersion;
}
- (float)batteryLevel {
    return randomBattery;
}
- (BOOL)isBatteryMonitoringEnabled {
    return YES;
}
%end

// 3. دقة الشاشة ومقياس العرض الآمن
%hook UIScreen
- (CGFloat)scale {
    return randomScale;
}
%end

// 4. اللغة والمنطقة الزمنية
%hook NSLocale
+ (NSString *)preferredLanguages {
    return (NSString *)randomLocale;
}
- (NSString *)localeIdentifier {
    return randomLocale;
}
%end

%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:randomTimeZone];
}
- (NSString *)name {
    return randomTimeZone;
}
%end
