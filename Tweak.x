#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *rotatingIDFA = nil;
static NSString *rotatingUUID = nil;
static NSString *randomLocale = nil;
static NSString *randomTimeZone = nil;
static NSString *randomModel = nil;
static NSString *randomSystemVersion = nil;
static float randomBattery = 0.5f;
static NSUInteger randomMemoryGB = 4;
static CGFloat randomScale = 2.0f;

static void generateUltimateFingerprintPersona() {
    // 1. المعرفات والإعلانات تتغير
    rotatingIDFA = [[NSUUID UUID] UUIDString];
    rotatingUUID = [[NSUUID UUID] UUIDString];
    
    // 2. لغة ونطاق عشوائي
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"en_AU"];
    randomLocale = locales[arc4random_uniform((uint32_t)locales.count)];
    
    // 3. منطقة زمنية عشوائية
    NSArray *timeZones = @[@"America/New_York", @"America/Chicago", @"America/Los_Angeles", @"Europe/London"];
    randomTimeZone = timeZones[arc4random_uniform((uint32_t)timeZones.count)];
    
    // 4. موديلات أجهزة مختلفة (لإخفاء جهازك الحقيقي تماماً)
    NSArray *models = @[@"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2", @"iPhone14,2"];
    randomModel = models[arc4random_uniform((uint32_t)models.count)];
    
    // 5. إصدارات نظام مختلفة
    NSArray *versions = @[@"17.4", @"17.5", @"18.0", @"18.1", @"26.6"];
    randomSystemVersion = versions[arc4random_uniform((uint32_t)versions.count)];
    
    // 6. نسبة بطارية ورامات وسطوع عشوائية
    randomBattery = (float)(arc4random_uniform(85) + 10) / 100.0f;
    NSArray *ramSizes = @[@4, @6, @8];
    randomMemoryGB = [ramSizes[arc4random_uniform((uint32_t)ramSizes.count)] unsignedIntegerValue];
    
    // 7. دقة الشاشة ومقياس العرض (Scale) عشوائي
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
        lbl.text = @"🔒 Device & Fingerprint Spoofer Active";
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

// 1. (UDID / identifierForVendor متروك بحالته الطبيعية تماماً بناءً على طلبك)

// 2. معرفات الإعلانات والـ UUID
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

// 3. تغيير موديل الجوال وإصدار النظام
%hook UIDevice
- (NSString *)model {
    return @"iPhone";
}
- (NSString *)systemName {
    return @"iOS";
}
- (NSString *)systemVersion {
    return randomSystemVersion;
}
- (NSString *)machine {
    return randomModel;
}
- (float)batteryLevel {
    return randomBattery;
}
- (BOOL)isBatteryMonitoringEnabled {
    return YES;
}
- (unsigned long long)totalMemory {
    return randomMemoryGB * 1024ULL * 1024ULL * 1024ULL;
}
%end

// 4. تغيير دقة الشاشة ومقياس العرض (Screen Scale & Resolution)
%hook UIScreen
- (CGFloat)scale {
    return randomScale;
}
- (CGRect)bounds {
    CGRect b = %orig;
    // تبديل طفيف في أبعاد الشاشة الوهمية
    if (arc4random_uniform(2) == 0) {
        b.size.height = b.size.height + (arc4random_uniform(5) - 2);
    }
    return b;
}
%end

// 5. اللغة والمنطقة الزمنية
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
