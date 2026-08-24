#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *randomUDID = nil;
static NSUUID *randomIDFA = nil;
static NSString *randomDeviceName = nil;

void generateNewDeviceIdentities() {
    // 1. توليد هوية جديدة بالكامل (UDID & IDFA & Device Name)
    randomUDID = [[NSUUID UUID] UUIDString];
    randomIDFA = [NSUUID UUID];
    
    NSArray *deviceNames = @[@"iPhone 15 Pro", @"iPhone 14 Pro", @"iPhone 16", @"iPhone 16 Pro Max", @"iPhone 15"];
    randomDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];
    
    // 2. التنظيف الجذري لملفات الـ Plist والـ UserDefaults الخاصة بالتطبيق لضمان صفحة نظيفة
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // مسح ملفات الإعدادات المخزنة في مسار الـ Preferences للملف الشخصي للتطبيق
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDirectory = [paths firstObject];
        NSString *prefsPath = [libraryDirectory stringByAppendingPathComponent:@"Preferences"];
        NSString *plistPath = [prefsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
        }
    }
}

// ---------------------------------------------------------
// 1. خداع معرفات الجهاز الأساسية (UDID & IDFV)
// ---------------------------------------------------------
%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!randomUDID) {
        generateNewDeviceIdentities();
    }
    return [[NSUUID alloc] initWithUUIDString:randomUDID];
}

- (NSString *)name {
    if (!randomDeviceName) {
        generateNewDeviceIdentities();
    }
    return randomDeviceName;
}

- (NSString *)systemName {
    return @"iOS";
}

- (NSString *)systemVersion {
    NSArray *versions = @[@"17.5.1", @"18.1", @"17.4.1", @"18.0"];
    return versions[arc4random_uniform((uint32_t)versions.count)];
}

%end

// ---------------------------------------------------------
// 2. خداع معرف الإعلانات (IDFA)
// ---------------------------------------------------------
%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if (!randomIDFA) {
        generateNewDeviceIdentities();
    }
    return randomIDFA;
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end

// ---------------------------------------------------------
// 3. خداع إصدار البناء والمعرفات داخل الـ Bundle
// ---------------------------------------------------------
%hook NSBundle

- (NSDictionary *)infoDictionary {
    NSMutableDictionary *dict = [%orig mutableCopy];
    dict[@"CFBundleVersion"] = [NSString stringWithFormat:@"%d.0", arc4random_uniform(10) + 1];
    dict[@"CFBundleShortVersionString"] = @"3.0.0";
    return dict;
}

%end

// ---------------------------------------------------------
// 4. التنفيذ الفوري عند تشغيل التطبيق
// ---------------------------------------------------------
%ctor {
    generateNewDeviceIdentities();
}
