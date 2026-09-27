#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Security/Security.h>

// متغيرات لتثبيت المعرفات طوال فترة الجلسة الحالية
static NSString *currentSessionUUID = nil;
static NSString *currentUserId = nil;
static NSString *currentDeviceToken = nil;
static NSString *currentVoipToken = nil;
static NSString *currentDeveloperId = nil;
static NSString *currentVendorID = nil;
static NSString *currentAdID = nil;
static NSString *currentDeviceName = nil;

// دالة مساعدة لتوليد سلسلة Hex بأطوال محددة
static NSString *randomHexString(NSUInteger length) {
    char *bytes = malloc(length);
    for (NSUInteger i = 0; i < length; i++) {
        bytes[i] = "0123456789abcdef"[arc4random_uniform(16)];
    }
    NSString *result = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    free(bytes);
    return result;
}

// دالة لتوليد UpperCase Hex (لمطابقة الـ App Instance ID)
static NSString *randomUpperCaseHex(NSUInteger length) {
    char *bytes = malloc(length);
    for (NSUInteger i = 0; i < length; i++) {
        bytes[i] = "0123456789ABCDEF"[arc4random_uniform(16)];
    }
    NSString *result = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    free(bytes);
    return result;
}

// 1. مسح الـ Keychain بالكامل باستثناء العنصر المحمي
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

// 2. مسح مجلدات الـ Sandbox والـ Library بالكامل
static void clearAppSandboxAggressive() {
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
    
    NSString *libraryPath = [homeDir stringByAppendingPathComponent:@"Library"];
    if ([fileManager fileExistsAtPath:libraryPath]) {
        NSArray *libContents = [fileManager contentsOfDirectoryAtPath:libraryPath error:nil];
        for (NSString *item in libContents) {
            NSString *fullPath = [libraryPath stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:nil];
        }
    }
}

// 3. توليد المعرفات بنفس الصيغة الهيكلية المعقدة تماماً
static void generateSessionIdentifiers() {
    currentSessionUUID = [[NSUUID UUID] UUIDString];
    currentUserId = [[NSUUID UUID] UUIDString];
    currentDeveloperId = [[NSUUID UUID] UUIDString];
    currentVendorID = [[NSUUID UUID] UUIDString];
    currentAdID = [[NSUUID UUID] UUIDString];
    
    NSArray *deviceNames = @[@"iPhone", @"iPhone 13", @"iPhone 14 Pro", @"iPhone 15", @"My iPhone", @"Phone"];
    currentDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];
    
    // توليد تواقيت زمنية عشوائية مقاربة للوقت الحالي بالـ Milliseconds
    long long currentTimestampMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    double currentTimestampSec = (double)currentTimestampMs / 1000.0;
    
    // بناء قالب PingMe_Device_Token بالحرف مطابَقاً لطلبك
    NSString *prefixHash = randomHexString(64); // الـ 64 خانة الأولى
    NSString *appInstanceId = randomUpperCaseHex(32); // الـ App Instance ID
    NSString *diversionKey = randomUpperCaseHex(5); // مثل D838D
    NSString *hashedIdfa = randomHexString(32); // مثل 848e3551...
    
    currentDeviceToken = [NSString stringWithFormat:
        @"\"%@]ple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
         "<plist version=\"1.0\">\n"
         "<dict>\n"
         "\t<key>/google/measurement/app_instance_id</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/app_version</key>\n"
         "\t<string>1.9.4</string>\n"
         "\t<key>/google/measurement/diversion_key</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/first_open_timestamp_ms</key>\n"
         "\t<integer>%lld</integer>\n"
         "\t<key>/google/measurement/gmp_app_id</key>\n"
         "\t<string>1:348263290411:ios:4a119dcfb912c688</string>\n"
         "\t<key>/google/measurement/hashed_idfa</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/last_delete_stale</key>\n"
         "\t<real>%f</real>\n"
         "\t<key>/google/measurement/last_engagement_end</key>\n"
         "\t<real>%f</real>\n"
         "\t<key>/google/measurement/midnight_offset</key>\n"
         "\t<real>66747.528999999995</real>\n"
         "\t<key>/google/measurement/os_version</key>\n"
         "\t<string>26.6.1</string>\n"
         "\t<key>/google/measurement/session_number</key>\n"
         "\t<integer>1</integer>\n"
         "</dict>\n"
         "</plist>",
         prefixHash, appInstanceId, diversionKey, currentTimestampMs, hashedIdfa, currentTimestampSec, (currentTimestampSec + 12.0)];
    
    // بناء قالب PingMe_VOIP_Token بنفس الهيكل والسلسلة الطويلة مع علامة الإغلاق "]
    NSString *voipPart1 = randomHexString(64);
    NSString *voipPart2 = randomHexString(32);
    currentVoipToken = [NSString stringWithFormat:@"\"%@%@\"]", voipPart1, voipPart2];
}

// 4. تطبيق القيم الجديدة في NSUserDefaults
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
    [defaults setObject:currentVoipToken forKey:@"PingMe_VOIP_Token"];
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

// التنفيذ الفوري عند تشغيل التطبيق
%ctor {
    clearAppSandboxAggressive();
    clearKeychainExceptProtected();
    generateSessionIdentifiers();
    resetAndSetSessionUserDefaults();
}

// 5. حماية (Hook) لمنع إعادة كتابة أو استرجاع القيم القديمة
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"PingMe_Device_Token"]) {
        return currentDeviceToken;
    }
    if ([defaultName isEqualToString:@"PingMe_VOIP_Token"]) {
        return currentVoipToken;
    }
    if ([defaultName isEqualToString:@"igg-userId"]) {
        return currentUserId;
    }
    if ([defaultName isEqualToString:@"device_name"]) {
        return currentDeviceName;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"PingMe_Device_Token"] && currentDeviceToken) {
        %orig(currentDeviceToken, defaultName);
        return;
    }
    if ([defaultName isEqualToString:@"PingMe_VOIP_Token"] && currentVoipToken) {
        %orig(currentVoipToken, defaultName);
        return;
    }
    %orig;
}

%end

// 6. تثبيت معرف البائع واسم الجهاز
%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentVendorID];
}

- (NSString *)name {
    return currentDeviceName;
}

%end

// 7. تثبيت معرف الإعلانات
%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:currentAdID];
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end
