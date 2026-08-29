#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *rotatingIDFA = nil;
static NSString *rotatingUUID = nil;
static NSString *rotatingMAC = nil;
static float randomBattery = 0.5f;

static void generateStablePersona() {
    // 1. معرفات الإعلانات والـ UUID تتجدد في كل إقلاع
    rotatingIDFA = [[NSUUID UUID] UUIDString];
    rotatingUUID = [[NSUUID UUID] UUIDString];
    
    // 2. توليد ماك أدرس عشوائي ومتجدد لكل إقلاع
    rotatingMAC = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256),
                   arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
    
    // 3. نسبة بطارية عشوائية لكل جلسة
    randomBattery = (float)(arc4random_uniform(85) + 10) / 100.0f;
}

@interface StableFingerprintHUD : NSObject
+ (void)showStatus;
@end

@implementation StableFingerprintHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 310, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.7 alpha:0.95];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"🛡️ Clean Fingerprint Spoofer Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    generateStablePersona();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [StableFingerprintHUD showStatus];
    });
}

// 1. معرف الإعلانات يتجدد
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:rotatingIDFA];
}
%end

// 2. الـ UUID العام يتجدد
%hook NSUUID
- (instancetype)initWithUUIDString:(NSString *)string {
    return %orig(rotatingUUID);
}
%end

// 3. البطارية تتغير عشوائياً في كل إقلاع
%hook UIDevice
- (float)batteryLevel {
    return randomBattery;
}
- (BOOL)isBatteryMonitoringEnabled {
    return YES;
}
%end
