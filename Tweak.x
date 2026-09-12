#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

static void resetKeychainAndRestoreAccountOnce() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            // 1. مسح جميع عناصر الـ Keychain الخاصة بالتطبيق بالكامل
            NSDictionary *query = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecReturnRef: @YES
            };
            
            CFArrayRef result = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            
            if (status == errSecSuccess && result) {
                NSArray *items = (NSArray *)result;
                for (NSDictionary *item in items) {
                    NSString *service = [item objectForKey:(__bridge id)kSecAttrService];
                    NSString *account = [item objectForKey:(__bridge id)kSecAttrAccount];
                    
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:@{
                        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                        (__bridge id)kSecAttrService: service ? service : @""
                    }];
                    if (account) {
                        [delQuery setObject:account forKey:(__bridge id)kSecAttrAccount];
                    }
                    
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
                CFRelease(result);
            }
            
            // 2. إعادة إدراج مفتاحي حسابك الأساسية
            NSString *targetService = @"app.getsmscode";
            
            // مفتاح deviceTokenKey
            NSDictionary *addQuery1 = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrService: targetService,
                (__bridge id)kSecAttrAccount: @"deviceTokenKey",
                (__bridge id)kSecValueData: [@"D9D117D6572F7E1F5F29F413B99FD01D3F07A2E3B684B6A8BDF-BC60975AE81CE" dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((__bridge CFDictionaryRef)addQuery1, NULL);
            
            // مفتاح tokenKey
            NSDictionary *addQuery2 = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrService: targetService,
                (__bridge id)kSecAttrAccount: @"tokenKey",
                (__bridge id)kSecValueData: [@"qqDS_DODP-uFvNZGYrfn9sCW" dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((__bridge CFDictionaryRef)addQuery2, NULL);
        }
    });
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    resetKeychainAndRestoreAccountOnce();
    return %orig;
}

%end
