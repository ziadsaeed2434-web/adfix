#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

// دالة لتوليد UUID عشوائي جديد
static NSString *generateRandomUUID() {
    return [[NSUUID UUID] UUIDString];
}

// دالة لتحديث أو إضافة القيمة في الـ Keychain
static void updateKeychainItem(NSString *service, NSString *account, NSString *newValue) {
    NSData *valueData = [newValue dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass,
        service, (__bridge id)kSecAttrService,
        account, (__bridge id)kSecAttrAccount,
        nil];
    
    NSDictionary *updateDict = [NSDictionary dictionaryWithObject:valueData forKey:(__bridge id)kSecValueData];
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)updateDict);
    
    if (status == errSecItemNotFound) {
        NSMutableDictionary *addDict = [NSMutableDictionary dictionaryWithDictionary:query];
        [addDict setObject:valueData forKey:(__bridge id)kSecValueData];
        SecItemAdd((__bridge CFDictionaryRef)addDict, NULL);
    }
}

// دالة لتوليد وتطبيق نفس الـ UDID الجديد على العنصرين
static void refreshDeviceIDsOncePerLaunch() {
    // نستخدم متغير للتأكد من تغييرها مع كل تشغيل جديد للتطبيق
    static dispatch_once_t onceToken;
    // إذا أردت أن تتغير في كل مرة تفتح فيها التطبيق من جديد، سنقوم بتوليد قيمة جديدة عند تشغيل الـdidFinishLaunching
    NSString *newUDID = generateRandomUUID();
    
    updateKeychainItem(@"unique_device_id", @"unique_device_id", newUDID);
    updateKeychainItem(@"deviceUID", @"deviceUID", newUDID);
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // هذه الدالة لا يتم استدعاؤها إلا عندما تفتح التطبيق بعد إغلاقه نهائياً (Kill)
    // لذلك في كل مرة تخرج نهائياً وتفتحه، سيتغير الـ UDID لقيمة جديدة ومتطابقة تماماً
    refreshDeviceIDsOncePerLaunch();
    
    return %orig;
}

%end
