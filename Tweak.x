#import <Foundation/Foundation.h>
#import <Security/Security.h>

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // تنفيذ الحذف عند فتح التطبيق لأول مرة
    [self clearKeychainExceptExemptions];
    return %orig;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // تنفيذ الحذف أيضاً في كل مرة يعود فيها التطبيق للواجهة (الفتح من الخلفية)
    [self clearKeychainExceptExemptions];
    %orig;
}

%new
- (void)clearKeychainExceptExemptions {
    @autoreleasepool {
        NSString *targetService = @"app.getsmscode";
        NSArray *exemptAccounts = @[@"deviceTokenKey", @"tokenKey"];
        
        NSDictionary *query = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecReturnRef: @YES
        };
        
        CFArrayRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        
        if (status == errSecSuccess && result) {
            NSArray *items = (__bridge_transfer NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(__bridge id)kSecAttrService];
                NSString *account = item[(__bridge id)kSecAttrAccount];
                
                // الاستثناء والحفاظ على المفتاحين المطلوبين فقط
                if ([service isEqualToString:targetService] && [exemptAccounts containsObject:account]) {
                    continue;
                }
                
                NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:@{
                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                    (__bridge id)kSecAttrService: service ? service : @""
                }];
                if (account) {
                    delQuery[(__bridge id)kSecAttrAccount] = account;
                }
                
                SecItemDelete((__bridge CFDictionaryRef)delQuery);
            }
        }
    }
}

%end
