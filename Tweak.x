#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self clearKeychainExceptExemptions];
    return %orig;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
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
            NSArray *items = (NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = [item objectForKey:(__bridge id)kSecAttrService];
                NSString *account = [item objectForKey:(__bridge id)kSecAttrAccount];
                
                if ([service isEqualToString:targetService] && [exemptAccounts containsObject:account]) {
                    continue;
                }
                
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
    }
}

%end
