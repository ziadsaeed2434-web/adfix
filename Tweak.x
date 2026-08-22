#import <UIKit/UIKit.h>

// 1. تنظيف ملفات التطبيق المحلية (Sandbox) بالكامل
void clearAppSandbox() {
    NSString *homeDir = NSHomeDirectory();
    NSArray *foldersToClean = @[
        @"Documents",
        @"Library/Caches",
        @"Library/Preferences",
        @"Library/Application Support",
        @"tmp"
    ];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *folder in foldersToClean) {
        NSString *folderPath = [homeDir stringByAppendingPathComponent:folder];
        if ([fileManager fileExistsAtPath:folderPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [folderPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
}

// 2. مسح الإعدادات المؤقتة NSUserDefaults
void clearUserDefaults() {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

// 3. واجهة الزر العائم
@interface ResetHelperWindow : NSObject
+ (void)addButtonToWindow:(UIWindow *)window;
@end

@implementation ResetHelperWindow

+ (void)addButtonToWindow:(UIWindow *)window {
    if ([window viewWithTag:9999]) return;

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.frame = CGRectMake(15, 50, 140, 35);
    [resetButton setTitle:@"Reset App 🔄" forState:UIControlStateNormal];
    resetButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.85];
    [resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetButton.layer.cornerRadius = 8;
    resetButton.tag = 9999;
    
    // عند الضغط، يتم التنظيف العميق بدون لمس الـ Keychain
    [resetButton addTarget:self action:@selector(performFullReset) forControlEvents:UIControlEventTouchUpInside];
    
    [window addSubview:resetButton];
    [window bringSubviewToFront:resetButton];
}

+ (void)performFullReset {
    // التنظيف الشامل للملفات
    clearAppSandbox();
    clearUserDefaults();
    
    // لا يتم لمس الـ Keychain نهائياً لضمان عدم فقدان أي بيانات
    exit(0);
}

@end

// 4. الهوك لإظهار الزر فور فتح التطبيق
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [ResetHelperWindow addButtonToWindow:self];
}

%end
