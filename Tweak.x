#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSString *const kServiceKey = @"com.codebysms";
static NSString *const kAccountUserID = @"userIDKey";
static NSString *const kAccountToken = @"accessTokenKey";

// قائمة الحسابات الـ 10
NSArray *getAccountsList() {
    return @[
        @{@"user": @"61178", @"token": @"30fG3UW6M0ZK-naaub4SPaVua"},
        // أضف باقي الحسابات هنا...
    ];
}

// دالة لحذف ملفات التطبيق بالكامل (Documents & Caches)
void clearApplicationFiles() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homeDir = NSHomeDirectory();
    
    // مسار مجلد المستندات والكاش
    NSArray *pathsToClean = @[
        [homeDir stringByAppendingPathComponent:@"Documents"],
        [homeDir stringByAppendingPathComponent:@"Library/Caches"],
        [homeDir stringByAppendingPathComponent:@"Library/Preferences"] // اختياري حسب الحاجة
    ];
    
    for (NSString *path in pathsToClean) {
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
        for (NSString *file in contents) {
            NSString *fullPath = [path stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:fullPath error:nil];
        }
    }
}

// دالة لحذف الـ Keychain بالكامل الخاص بالخدمة
void clearKeychain() {
    NSDictionary *spec = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceKey
    };
    SecItemDelete((__bridge CFDictionaryRef)spec);
}

// دالة لإضافة قيمة إلى الـ Keychain
void saveToKeychain(NSString *accountName, NSString *passwordVal) {
    NSData *passwordData = [passwordVal dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *spec = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceKey,
        (__bridge id)kSecAttrAccount: accountName,
        (__bridge id)kSecValueData: passwordData
    };
    SecItemAdd((__bridge CFDictionaryRef)spec, NULL);
}

void setupAccountSwitcher() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger currentIndex = [defaults integerForKey:@"CurrentAccountIndex"];
    
    NSArray *accounts = getAccountsList();
    if (currentIndex >= [accounts count]) {
        currentIndex = 0;
    }
    
    NSDictionary *currentAcc = accounts[currentIndex];
    
    // 1. حذف ملفات التطبيق أولاً
    clearApplicationFiles();
    
    // 2. حذف الـ Keychain كاملاً
    clearKeychain();
    
    // 3. حقن بيانات الحساب الجديد في الـ Keychain
    saveToKeychain(kAccountUserID, currentAcc[@"user"]);
    saveToKeychain(kAccountToken, currentAcc[@"token"]);
    
    // الانتقال للحساب التالي في المرة القادمة
    [defaults setInteger:(currentIndex + 1) % [accounts count] forKey:@"CurrentAccountIndex"];
    [defaults synchronize];
}

%ctor {
    @autoreleasepool {
        setupAccountSwitcher();
    }
}
