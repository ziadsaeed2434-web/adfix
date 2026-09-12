#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

static void clearEverythingAndRestoreAccount() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            // 1. مسح جميع محتويات مجلد الحاوية (Sandbox Container) بالكامل دون استثناء
            NSString *homeDir = NSHomeDirectory();
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSArray *foldersToClean = @[@"Documents", @"Library", @"tmp", @"SystemData"];
            for (NSString *folderName in foldersToClean) {
                NSString *folderPath = [homeDir stringByAppendingPathComponent:folderName];
                if ([fileManager fileExistsAtPath:folderPath]) {
                    NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
                    for (NSString *item in contents) {
                        NSString *itemPath = [folderPath stringByAppendingPathComponent:item];
                        [fileManager removeItemAtPath:itemPath error:nil];
                    }
                }
            }
            
            // 2. مسح عناصر الـ Keychain بالكامل
            NSDictionary *query = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecReturnRef: @YES
            };
            
            CFArrayRef result = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            
            if (status == errSecSuccess && result) {
                NSArray *itemsArr = (__bridge_transfer NSArray *)result;
                for (NSDictionary *item in itemsArr) {
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
            }
            
            // 3. إعادة إدراج مفتاحي حسابك فقط ليبقى التطبيق فاتحاً على حسابك دون خروج
            NSString *targetService = @"app.getsmscode";
            
            NSDictionary *addQuery1 = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrService: targetService,
                (__bridge id)kSecAttrAccount: @"deviceTokenKey",
                (__bridge id)kSecValueData: [@"D9D117D6572F7E1F5F29F413B99FD01D3F07A2E3B684B6A8BDF-BC60975AE81CE" dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((__bridge CFDictionaryRef)addQuery1, NULL);
            
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
    clearEverythingAndRestoreAccount();
    return %orig;
}

%end
