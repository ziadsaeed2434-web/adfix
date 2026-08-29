#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *rotatingIDFA = nil;
static NSString *rotatingMAC = nil;
static NSString *rotatingUUID = nil;
static NSString *randomLocale = nil;
static float randomBattery = 0.5f;

static void generateAdvancedFingerprintPersona() {
    // 1. معرف تتبع الإعلانات (IDFA) يتغير
    rotatingIDFA = [[NSUUID UUID] UUIDString];
    
    // 2. ماك أدرس وهمي متجدد
    rotatingMAC = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256),
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
                   
    // 3. UUID عام متجدد
    rotatingUUID = [[NSUUID UUID] UUIDString];
    
    // 4. تغيير لغة ووحدة المعاينة عشوائياً (أمريكي، بريطاني، كندي...)
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"en_AU"];
    randomLocale = locales[arc4random_uniform((uint32_t)locales.count)];
    
    // 5. نسبة بطارية عشوائية لكل جلسة
    randomBattery = (float)(arc4random_uniform(80) + 15) / 100.0f;
}

@interface FingerprintRotatorHUD : NSObject
+ (void)showStatus;
@end

@implementation FingerprintRotatorHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 290, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"🕶️ Advanced Fingerprint Rotator Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    generateAdvancedFingerprintPersona();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [FingerprintRotatorHUD showStatus];
    });
}

// 1. (ملاحظة: تم ترك الـ UDID / identifierForVendor كما هو بدون تغيير بناءً على طلبك)

// 2. تغيير معرف الإعلانات (IDFA) في كل إقلاع
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:rotatingIDFA];
}
%end

// 3. تزوير الاستعلامات العامة للـ UUID
%hook NSUUID
- (instancetype)initWithUUIDString:(NSString *)string {
    return %orig(rotatingUUID);
}
%end

// 4. تزوير لغة الجهاز المبلّغ عنها لكسر بصمة الموقع واللغة
%hook NSLocale
+ (NSString *)preferredLanguages {
    return (NSString *)randomLocale;
}
- (NSString *)localeIdentifier {
    return randomLocale;
}
%end

// 5. تزوير نسبة وطاقة البطارية (تعتبر جزءاً أساسياً من الـ Fingerprinting)
%hook UIDevice
- (float)batteryLevel {
    return randomBattery;
}
- (BOOL)isBatteryMonitoringEnabled {
    return YES;
}
%end
