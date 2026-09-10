#import <Foundation/Foundation.h>
#import <Security/Security.h>

// المتغيرات العامة لحفظ الجلسة
static NSString *currentDynamicBundleID = nil;
static NSString *persistedUserID = nil;
static NSString *persistedAccessToken = nil;

// توليد بندل عشوائي جديد مع كل فتحة
NSString *generateNewRandomBundleID() {
    NSString *baseBundle = @"com.codebysms";
    int randomSuffix = arc4random_uniform(90000) + 10000;
    return [NSString stringWithFormat:@"%@.%d", baseBundle, randomSuffix];
}

// استرجاع الحساب من الـ Keychain قبل تغيير الهوية لمنع ضياعه
void backupAccountData() {
    @autoreleasepool {
        NSDictionary *query = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecMatchLimit: (id)kSecMatchLimitAll,
            (id)kSecReturnAttributes: @YES,
            (id)kSecReturnData: @YES
        };
        CFArrayRef result = NULL;
        OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status == errSecSuccess && result != NULL) {
            NSArray *items = (__bridge NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(id)kSecAttrService];
                NSString *account = item[(id)kSecAttrAccount];
                NSData *valueData = item[(id)kSecValueData];
                NSString *value = valueData ? [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding] : @"";
                
                if ([account isEqualToString:@"userIDKey"]) {
                    persistedUserID = value;
                } else if ([account isEqualToString:@"accessTokenKey"]) {
                    persistedAccessToken = value;
                }
            }
            CFRelease(result);
        }
    }
}

// إعادة حقن الحساب المحفوظ في الـ Keychain بالبندل الجديد لضمان عدم الخروج
void restoreAccountData() {
    @autoreleasepool {
        if (persistedUserID) {
            NSDictionary *addQuery = @{
                (id)kSecClass: (id)kSecClassGenericPassword,
                (id)kSecAttrService: @"com.codebysms",
                (id)kSecAttrAccount: @"userIDKey",
                (id)kSecValueData: [persistedUserID dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((CFDictionaryRef)addQuery, NULL);
        }
        if (persistedAccessToken) {
            NSDictionary *addQuery = @{
                (id)kSecClass: (id)kSecClassGenericPassword,
                (id)kSecAttrService: @"com.codebysms",
                (id)kSecAttrAccount: @"accessTokenKey",
                (id)kSecValueData: [persistedAccessToken dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((CFDictionaryRef)addQuery, NULL);
        }
    }
}

%ctor {
    @autoreleasepool {
        // 1. أخذ نسخة احتياطية من الحساب الحالي
        backupAccountData();
        
        // 2. توليد بندل جديد لهذه الجلسة
        currentDynamicBundleID = generateNewRandomBundleID();
        
        // 3. إعادة حقن الحساب لكي يظل مسجلاً ولا يتأثر بتغيير البندل
        restoreAccountData();
    }
}

%hook NSBundle

// خداع الـ NSBundle ليعطي البندل العشوائي الجديد للنظام والإعلانات
- (NSString *)bundleIdentifier {
    if (self == [NSBundle mainBundle] && currentDynamicBundleID) {
        return currentDynamicBundleID;
    }
    return %orig;
}

// خداع الـ Info.plist ليتوافق مع البندل الجديد تماماً
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *dict = [%orig mutableCopy];
    if (dict && currentDynamicBundleID) {
        [dict setObject:currentDynamicBundleID forKey:@"CFBundleIdentifier"];
    }
    return dict;
}

%end
