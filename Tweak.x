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

// دالة لتوليد وتطبيق نفس الـ UDID الجديد على العنصرين في كل فتحة تطبيق جديدة
static void refreshDeviceIDsOncePerLaunch() {
    NSString *newUDID = generateRandomUUID();
    
    updateKeychainItem(@"unique_device_id", @"unique_device_id", newUDID);
    updateKeychainItem(@"deviceUID", @"deviceUID", newUDID);
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // يتم تنفيذه فور فتح التطبيق بعد إغلاقه نهائياً، لتغيير القيم بقيم جديدة ومتطابقة
    refreshDeviceIDsOncePerLaunch();
    
    return %orig;
}

%end
