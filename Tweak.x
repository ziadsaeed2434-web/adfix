#import <UIKit/UIKit.h>
#import <Security/Security.h>

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
    }
}

// 3. تنظيف الـ Keychain بالكامل مع استثناء حسابك ونقاطك (userIDKey)
void clearKeychainExceptToken() {
    NSString *serviceToKeep = @"com.codebysms";
    NSString *accountToKeep = @"userIDKey";

    NSArray *secItemClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword
    ];

    for (id secClass in secItemClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
        };

        CFArrayRef items = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&items) == errSecSuccess) {
            NSArray *itemsArray = (__bridge_transfer NSArray *)items;

            for (NSDictionary *itemDict in itemsArray) {
                NSString *service = itemDict[(__bridge id)kSecAttrService];
                NSString *account = itemDict[(__bridge id)kSecAttrAccount];

                // حذف كل شيء تابع للتطبيق ما عدا مفتاح الحساب المستثنى
                if ([service isEqualToString:serviceToKeep] && ![account isEqualToString:accountToKeep]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:@{
                        (__bridge id)kSecClass: secClass,
                        (__bridge id)kSecAttrService: service,
                        (__bridge id)kSecAttrAccount: account
                    }];
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
        }
    }
}

// 4. واجهة البرمجية للزر العائم وعملية التنفيذ
@interface ResetHelperWindow : NSObject
+ (void)addButtonToWindow:(UIWindow *)window;
@end

@implementation ResetHelperWindow

+ (void)addButtonToWindow:(UIWindow *)window {
    // منع تكرار إنشاء الزر إذا كان موجوداً مسبقاً
    if ([window viewWithTag:9999]) return;

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.frame = CGRectMake(15, 50, 140, 35);
    [resetButton setTitle:@"Reset App 🔄" forState:UIControlStateNormal];
    resetButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.85];
    [resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetButton.layer.cornerRadius = 8;
    resetButton.tag = 9999;
    
    // ربط الزر بدالة التنفيذ عند الضغط
    [resetButton addTarget:self action:@selector(performFullReset) forControlEvents:UIControlEventTouchUpInside];
    
    [window addSubview:resetButton];
    [window bringSubviewToFront:resetButton];
}

+ (void)performFullReset {
    clearAppSandbox();
    clearUserDefaults();
    clearKeychainExceptToken();
    
    // إغلاق التطبيق ليفتح نظيفاً بالكامل في المرة القادمة
    exit(0);
}

@end

// 5. الهوك لإظهار الزر فور فتح التطبيق
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [ResetHelperWindow addButtonToWindow:self];
}

%end
