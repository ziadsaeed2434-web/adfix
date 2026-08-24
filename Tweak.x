#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AdSupport/ASIdentifierManager.h>

static NSString *randomUDID = nil;
static NSUUID *randomIDFA = nil;
static NSString *randomDeviceName = nil;

void generateNewDeviceIdentities() {
    // توليد هوية جديدة بالكامل في الذاكرة لتظهر كجهاز جديد
    randomUDID = [[NSUUID UUID] UUIDString];
    randomIDFA = [NSUUID UUID];
    
    NSArray *deviceNames = @[@"iPhone 15 Pro", @"iPhone 14 Pro", @"iPhone 16", @"iPhone 16 Pro Max", @"iPhone 15"];
    randomDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];
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
// 3. خداع إصدار البناء والمعرفات داخل الـ Bundle (بشكل آمن ومستقر)
// ---------------------------------------------------------
%hook NSBundle

- (NSDictionary *)infoDictionary {
    NSDictionary *origDict = %orig;
    if (!origDict) {
        return nil;
    }
    NSMutableDictionary *dict = [origDict mutableCopy];
    dict[@"CFBundleVersion"] = [NSString stringWithFormat:@"%d.0", arc4random_uniform(10) + 1];
    dict[@"CFBundleShortVersionString"] = @"3.0.0";
    return [dict copy];
}

%end

// ---------------------------------------------------------
// 4. التشغيل الفوري عند إطلاق التطبيق
// ---------------------------------------------------------
%ctor {
    generateNewDeviceIdentities();
}
