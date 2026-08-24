#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// متغيرات لتخزين المعرفات الوهمية الخاصة بهذا التشغيل
static NSString *randomUDID = nil;
static NSString *randomDeviceName = nil;

// دالة لتوليد قيم عشوائية جديدة عند فتح التطبيق
void generateNewDeviceIdentities() {
    // 1. توليد UDID عشوائي جديد كلياً (معرف البائع)
    randomUDID = [[NSUUID UUID] UUIDString];
    
    // 2. تغيير اسم الجهاز العشوائي لزيادة التمويه
    NSArray *deviceNames = @[@"iPhone 15 Pro", @"iPhone 14", @"iPhone 13 Pro Max", @"iPhone 15", @"iPhone 16"];
    randomDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];
}

// ---------------------------------------------------------
// خداع معرفات الجهاز (UDID, اسم الجهاز، وإصدار النظام)
// ---------------------------------------------------------
%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!randomUDID) {
        generateNewDeviceIdentities();
    }
    // إرجاع UDID وهمي جديد ثابت خلال هذه الجلسة، ومتغير عند إعادة فتح التطبيق
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
    // التنقل بين إصدارات آي أو إس عشوائياً لزيادة الخصوصية
    NSArray *versions = @[@"17.5", @"17.4.1", @"18.0", @"17.2"];
    return versions[arc4random_uniform((uint32_t)versions.count)];
}

%end

// ---------------------------------------------------------
// تفعيل توليد الهوية الجديدة فور إطلاق التطبيق
// ---------------------------------------------------------
%ctor {
    generateNewDeviceIdentities();
}
