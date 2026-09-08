#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSString *const kServiceKey = @"com.codebysms";
static NSString *const kAccountUserID = @"userIDKey";
static NSString *const kAccountToken = @"accessTokenKey";

NSArray *getAccountsList() {
    return @[
        @{@"user": @"61178", @"token": @"30fG3UW6M0ZK-naaub4SPaVua"},
        // أضف باقي الحسابات هنا...
    ];
}

// تعديل: حذف مفاتيح الـ Keychain الخاصة بالتطبيق فقط بدون تدمير مسار الكاش بالكامل لتجنب شاشة الخطأ
void clearKeychain() {
    NSDictionary *spec = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceKey
    };
    SecItemDelete((__bridge CFDictionaryRef)spec);
}

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
    
    // تفريغ الـ Keychain فقط لتحديث الحساب دون تدمير ملفات التشغيل
    clearKeychain();
    
    // حقن الحساب الجديد
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
