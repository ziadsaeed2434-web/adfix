#import <UIKit/UIKit.h>
#include <sys/sysctl.h>

// متغيرات للبصمة المتطورة
static NSString *currentModel = @"iPhone16,2";
static NSString *currentID = @"00000000-0000-0000-0000-000000000000";
static NSString *currentSystemVersion = @"17.5";
static NSString *currentDeviceName = @"Device";

@interface PowerSpoofer : NSObject
+ (void)generateHeavyFingerprint;
@end

@implementation PowerSpoofer
+ (void)generateHeavyFingerprint {
    // 1. موديلات حديثة ومتنوعة
    NSArray *models = @[@"iPhone14,2", @"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2", @"iPhone16,4"];
    currentModel = models[arc4random_uniform(models.count)];
    
    // 2. معرف فريد عشوائي كلياً
    currentID = [[NSUUID UUID] UUIDString];
    
    // 3. إصدارات نظام قريبة وحقيقية
    NSArray *versions = @[@"17.2", @"17.3.1", @"17.4", @"17.5", @"17.5.1"];
    currentSystemVersion = versions[arc4random_uniform(versions.count)];
    
    // 4. أسماء عشوائية للأجهزة
    NSArray *names = @[@"iPhone", @"My iPhone", @"Apple Device", @"User's iPhone"];
    currentDeviceName = names[arc4random_uniform(names.count)];
}
@end

// 1. تزييف جذري لبيانات UIDevice (الواجهة الأمامية لنظام الجهاز)
%hook UIDevice
- (NSString *)model { return currentModel; }
- (NSString *)localizedModel { return currentModel; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)systemVersion { return currentSystemVersion; }
- (NSString *)name { return currentDeviceName; }
- (NSString *)identifierForVendor { return currentID; }
- (NSString *)systemFontName { return @"SanFrancisco"; }
%end

// 2. تزييف عتاد الجهاز والأنوية والذاكرة العشوائية عبر NSProcessInfo
%hook NSProcessInfo
- (NSUInteger)activeProcessorCount {
    // تغيير عدد الأنوية عشوائياً بين 4 و 6
    return 4 + arc4random_uniform(3);
}
- (NSUInteger)processorCount {
    return 6;
}
- (unsigned long long)physicalMemory {
    // تزييف حجم الرام (6GB أو 8GB) لتبدو كأنك تستخدم هاتفاً مختلفاً تماماً
    return (arc4random_uniform(2) == 0) ? 6ULL * 1024ULL * 1024ULL * 1024ULL : 8ULL * 1024ULL * 1024ULL * 1024ULL;
}
- (NSString *)hostName {
    return [NSString stringWithFormat:@"iPhone-%d", arc4random_uniform(8999) + 1000];
}
%end

// 3. تزييف دقة الشاشة (Screen Metrics Spoofing) لكسر البصمة البصرية
%hook UIScreen
- (CGRect)bounds {
    CGRect b = %orig;
    // إضافة تغيير طفيف جداً لا يلاحظه المستخدم ولكن يغير البصمة الرياضية تماماً أمام السكربتات
    b.size.width += (arc4random_uniform(2) == 0 ? 0.02 : -0.02);
    return b;
}
- (CGFloat)scale {
    return 3.0;
}
%end

// 4. حجب أو منع تسجيل معرفات التتبع والإعلانات في الملفات المؤقتة
%hook NSUserDefaults
- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if ([defaultName containsString:@"IDFA"] || [defaultName containsString:@"advertising"] || [defaultName containsString:@"token"]) {
        return; // منع التطبيق من حفظ بصمات التتبع القديمة
    }
    %orig;
}
%end

// 5. نظام توليد الهوية التلقائي والزر العائم الآمن
%hook UIApplication
- (BOOL)application:(id)application didFinishLaunchingWithOptions:(id)launchOptions {
    [PowerSpoofer generateHeavyFingerprint];
    return %orig;
}
%end

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (![self viewWithTag:9999]) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(15, 60, 140, 32);
        btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.85];
        btn.layer.cornerRadius = 6;
        [btn setTitle:@"🛡️ Power ID" forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont boldSystemFontOfSize:11]];
        [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        btn.tag = 9999;
        
        [btn addTarget:self action:@selector(showPowerAlert) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [self bringSubviewToFront:btn];
    }
}

%new
- (void)showPowerAlert {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    
    if (rootVC) {
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        NSString *details = [NSString stringWithFormat:@"Model: %@\nVer: %@\nID: %@", currentModel, currentSystemVersion, [currentID substringToIndex:8]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🛡️ Power Spoofer Active" 
                                                                        message:details 
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}
%end
