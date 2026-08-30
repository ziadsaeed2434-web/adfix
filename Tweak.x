#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

// توليد هوية عشوائية جديدة بالكامل في كل مرة يفتح فيها التطبيق
static NSString *fakeHardwareID = nil;
static NSString *fakeVendorID = nil;

__attribute__((constructor)) static void customInit() {
    @autoreleasepool {
        // إنشاء بصمة هاردوير وهمية جديدة كلياً لتجاوز حظر السيرفر
        fakeHardwareID = [[NSUUID UUID] UUIDString];
        fakeVendorID = [[NSUUID UUID] UUIDString];
        
        // مسح أي معرفات قديمة مخزنة قد تربط التطبيق بالبصمة المحظورة
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"advertisingIdentifier"];
        [defaults removeObjectForKey:@"vendorIdentifier"];
        [defaults synchronize];
    }
}

// 1. خداع نظام الإعلانات ومعرف الـ IDFA المحظور
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:fakeHardwareID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// 2. خداع النظام بمعرف بائع (IDFV) وهمي جديد يمنع السيرفر من التعرف على الجهاز الحقيقي
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:fakeVendorID];
}
- (NSString *)systemName {
    return @"iOS";
}
- (NSString *)systemVersion {
    // محاكاة إصدار نظام آخر إذا لزم الأمر لإرباك بصمة السيرفر
    return @"17.5"; 
}
%end

// 3. تزوير الهيدرز المرسلة للسيرفر (إخفاء بصمة الجهاز الحقيقي من طلبات الـ API الخاصة بالإعلانات)
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString containsString:@"device"] || 
        [field.lowercaseString containsString:@"agent"] || 
        [field.lowercaseString containsString:@"identifier"] ||
        [field.lowercaseString containsString:@"udid"]) {
        // استبدال أي هيدر قد يفضح بصمة الجهاز الحقيقي بقيم وهمية نظيفة
        %orig([NSString stringWithFormat:@"CustomAgent-%@", fakeHardwareID], field);
        return;
    }
    %orig(value, field);
}
%end
