#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

// متغيرات لتخزين المعرفات الخاصة بالجلسة الحالية
static NSString *currentRandomUDID = nil;
static NSUUID *currentRandomIDFA = nil;

// دالة لتوليد UDID عشوائي صحيح بنسق UUID (مثال: E621E1F8-C36C-49DF-A3DF-823E6E85B203)
NSString* generateRandomUDIDString() {
    return [[NSUUID UUID] UUIDString];
}

// دالة لتوليد NSUUID عشوائي جديد للـ IDFA
NSUUID* generateRandomIDFAUUID() {
    return [NSUUID UUID];
}

// دالة التهيئة التي تعمل فور فتح التطبيق لتوليد هوية جديدة بالكامل
void initializeNewDeviceIdentity() {
    currentRandomUDID = generateRandomUDIDString();
    currentRandomIDFA = generateRandomIDFAUUID();
    NSLog(@"[RandomIdentity] تم توليد هوية جديدة للجلسة - UDID: %@ | IDFA: %@", currentRandomUDID, [currentRandomIDFA UUIDString]);
}

%ctor {
    // توليد معرفات جديدة فور تشغيل التطبيق
    initializeNewDeviceIdentity();
}

// اعتراض معرف البائع (UDID / identifierForVendor) وإرجاع المعرف العشوائي الجديد
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentRandomUDID) {
        initializeNewDeviceIdentity();
    }
    return [[NSUUID alloc] initWithUUIDString:currentRandomUDID];
}
%end

// اعتراض معرف الإعلانات (IDFA / advertisingIdentifier) وإرجاع المعرف العشوائي الجديد
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!currentRandomIDFA) {
        initializeNewDeviceIdentity();
    }
    return currentRandomIDFA;
}
%end
