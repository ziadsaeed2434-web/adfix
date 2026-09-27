#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Security/Security.h>

// متغيرات لتثبيت المعرفات طوال فترة الجلسة الواحدة
static NSString *currentSessionUUID = nil;
static NSString *currentUserId = nil;
static NSString *currentDeviceToken = nil;
static NSString *currentDeveloperId = nil;
static NSString *currentVendorID = nil;
static NSString *currentAdID = nil;
static NSString *currentDeviceName = nil;

// 1. مسح الـ Keychain بالكامل باستثناء العنصر المحمي (unique_device_id)
static void clearKeychainExceptProtected() {
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword
    ];
    
    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
        };
        
        CFArrayRef result = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess) {
            NSArray *items = (__bridge_transfer NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(__bridge id)kSecAttrService];
                NSString *account = item[(__bridge id)kSecAttrAccount];
                
                // استثناء العنصر المحمي بناءً على طلبك
                if ([service isEqualToString:@"unique_device_id"] || [account isEqualToString:@"unique_device_id"]) {
                    continue; 
                }
                
                NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                [delQuery setObject:secClass forKey:(__bridge id)kSecClass];
                [delQuery removeObjectForKey:(__bridge id)kSecReturnAttributes];
                [delQuery removeObjectForKey:(__bridge id)kSecMatchLimit];
                
                SecItemDelete((__bridge CFDictionaryRef)delQuery);
            }
        }
    }
}

// 2. مسح مجلد الـ Library بالكامل مع Documents و tmp من غير استثناء
static void clearAppSandbox() {
    NSString *homeDir = NSHomeDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *targetDirs = @[@"Documents", @"tmp"];
    for (NSString *dirName in targetDirs) {
        NSString *dirPath = [homeDir stringByAppendingPathComponent:dirName];
        if ([fileManager fileExistsAtPath:dirPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:dirPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [dirPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // حذف محتويات مجلد الـ Library بالكامل بدون استثناء
    NSString *libraryPath = [homeDir stringByAppendingPathComponent:@"Library"];
    if ([fileManager fileExistsAtPath:libraryPath]) {
        NSArray *libContents = [fileManager contentsOfDirectoryAtPath:libraryPath error:nil];
        for (NSString *item in libContents) {
            NSString *fullPath = [libraryPath stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:nil];
        }
    }
}

// 3. توليد وتثبيت المعرفات الخاصة بهذه الجلسة فقط (تتغير فقط عند فتح التطبيق من جديد)
static void generateSessionIdentifiers() {
    currentSessionUUID = [[NSUUID UUID] UUIDString];
    currentUserId = [[NSUUID UUID] UUIDString];
    currentDeviceToken = [[NSUUID UUID] UUIDString];
    currentDeveloperId = [[NSUUID UUID] UUIDString];
    currentVendorID = [[NSUUID UUID] UUIDString];
    currentAdID = [[NSUUID UUID] UUIDString];
    
    NSArray *deviceNames = @[@"iPhone", @"iPhone 13", @"iPhone 14 Pro", @"iPhone 15", @"My iPhone", @"Phone"];
    currentDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];
}

// 4. مسح وضخ المعرفات الثابتة الخاصة بهذه الجلسة في NSUserDefaults
static void resetAndSetSessionUserDefaults() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    
    for (NSString *key in dict.allKeys) {
        [defaults removeObjectForKey:key];
    }
    
    NSTimeInterval currentTimeMs = [[NSDate date] timeIntervalSince1970] * 1000;
    
    [defaults setObject:currentSessionUUID forKey:@"STASessionUUID"];
    [defaults setObject:currentUserId forKey:@"igg-userId"];
    [defaults setObject:currentDeviceToken forKey:@"PingMe_Device_Token"];
    [defaults setObject:currentDeveloperId forKey:@"STAStoredDeveloperUserId"];
    [defaults setObject:@(currentTimeMs) forKey:@"STACurrentSessionStartTime"];
    [defaults setObject:@(currentTimeMs) forKey:@"STIFirstSessionTime"];
    [defaults setObject:@(currentTimeMs) forKey:@"STAFirstSessionTime"];
    [defaults setObject:currentDeviceName forKey:@"device_name"];
    
    [defaults setInteger:1 forKey:@"STASessionsNum"];
    [defaults setBool:YES forKey:@"STAHtmlSplash"];
    [defaults setBool:YES forKey:@"STAAppPresenceEnable"];
    [defaults setBool:YES forKey:@"STALocalCache"];
    
    [defaults synchronize];
}

// التنفيذ التلقائي فور تشغيل التطبيق في كل مرة
%ctor {
    clearAppSandbox();
    clearKeychainExceptProtected();
    generateSessionIdentifiers();     // توليد معرفات جديدة خاصة بهذه الجلسة
    resetAndSetSessionUserDefaults(); // حفظها لتكون ثابته طوال فتحة التطبيق الحالية
}

// 5. تثبيت معرف البائع (Vendor ID) واسم الجهاز طوال الجلسة
%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentVendorID];
}

- (NSString *)name {
    return currentDeviceName;
}

%end

// 6. تثبيت معرف الإعلانات (Advertising Identifier) طوال الجلسة
%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:currentAdID];
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end
