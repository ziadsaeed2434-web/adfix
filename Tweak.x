#import <UIKit/UIKit.h>
#include <sys/utsname.h>

// متغيرات للبصمة الكاملة
static NSString *currentModel = @"iPhone16,2";
static NSString *currentID = @"00000000-0000-0000-0000-000000000000";
static NSString *currentSystemVersion = @"17.4";
static NSString *currentDeviceName = @"iPhone";

@interface FullFingerprintSpoofer : NSObject
+ (void)randomizeFingerprint;
@end

@implementation FullFingerprintSpoofer
+ (void)randomizeFingerprint {
    // 1. موديلات عشوائية حديثة
    NSArray *models = @[@"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2", @"iPhone16,4"];
    currentModel = models[arc4random_uniform(models.count)];
    
    // 2. معرّف عشوائي فريد جديد كلياً
    currentID = [[NSUUID UUID] UUIDString];
    
    // 3. إصدار نظام عشوائي قريب
    NSArray *versions = @[@"17.2", @"17.3.1", @"17.4", @"17.5"];
    currentSystemVersion = versions[arc4random_uniform(versions.count)];
    
    // 4. اسم جهاز عشوائي
    NSArray *names = @[@"My iPhone", @"iPhone (2)", @"User's Device", @"Phone"];
    currentDeviceName = names[arc4random_uniform(names.count)];
}
@end

// 1. تزييف هويات UIDevice بالكامل
%hook UIDevice
- (NSString *)model { return currentModel; }
- (NSString *)localizedModel { return currentModel; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)systemVersion { return currentSystemVersion; }
- (NSString *)name { return currentDeviceName; }
- (NSString *)identifierForVendor { return currentID; } // إرجاع النص مباشرة كـ NSString
%end

// 2. تزييف الـ Hardware والميموري والأنوية (عبر NSProcessInfo)
%hook NSProcessInfo
- (NSUInteger)activeProcessorCount {
    return 4 + arc4random_uniform(3);
}
- (unsigned long long)physicalMemory {
    return (arc4random_uniform(2) == 0) ? 6ULL * 1024ULL * 1024ULL * 1024ULL : 8ULL * 1024ULL * 1024ULL * 1024ULL;
}
- (NSString *)hostName {
    return [NSString stringWithFormat:@"iPhone-%d", arc4random_uniform(9000) + 1000];
}
%end

// 3. تزييف الشاشة ودقتها (UIScreen) لمنع البصمة البصرية
%hook UIScreen
- (CGRect)bounds {
    CGRect b = %orig;
    b.size.width += (arc4random_uniform(2) == 0 ? 0.01 : -0.01);
    return b;
}
- (CGFloat)scale {
    return 3.0;
}
%end

// 4. تزييف uname للمستوى المنخفض للنظام
%hookf(int, uname, struct utsname *name) {
    int result = %orig(name);
    if (result == 0 && name) {
        [currentModel getCString:name->machine maxLength:sizeof(name->machine) encoding:NSUTF8StringEncoding];
    }
    return result;
}

// 5. إدارة التوليد عند فتح التطبيق والزر العائم المتوافق مع الإصدارات الحديثة
%hook UIApplication
- (BOOL)application:(id)application didFinishLaunchingWithOptions:(id)launchOptions {
    [FullFingerprintSpoofer randomizeFingerprint];
    return %orig;
}
%end

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (![self viewWithTag:999]) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(15, 60, 130, 32);
        btn.backgroundColor = [UIColor darkGrayColor];
        btn.alpha = 0.8;
        btn.layer.cornerRadius = 6;
        [btn setTitle:@"Fingerprint 🔍" forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont boldSystemFontOfSize:11]];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.tag = 999;
        
        [btn addTarget:self action:@selector(showFullFingerprint) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [self bringSubviewToFront:btn];
    }
}

%new
- (void)showFullFingerprint {
    NSString *details = [NSString stringWithFormat:@"Model: %@\nVersion: %@\nID: %@", currentModel, currentSystemVersion, [currentID substringToIndex:8]];
    
    // استخدام الطريقة الحديثة لتجنب أخطاء التحذيرات في البناء
    UIViewController *rootVC = self.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Full Fingerprint Active" 
                                                                    message:details 
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:alert animated:YES completion:nil];
}
%end
