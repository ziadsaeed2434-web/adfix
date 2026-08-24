#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *generatedUUID = nil;

%ctor {
    // توليد معرف جديد كلياً نظيف تماماً عند كل عملية إقلاع
    generatedUUID = [[NSUUID UUID] UUIDString];
    
    // مسح مفاتيح الجلسة المؤقتة الخاصة بالتطبيق بلطف وبدون إحداث أي استثناء أو كراش
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
        }
    }
}

%hook UIDevice

// خداع معرف البائع بمعرف جديد كلياً مع كل تشغيل
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:generatedUUID];
}

- (NSString *)name {
    return @"iPhone";
}

- (NSString *)systemVersion {
    return @"17.5.1";
}

%end

// خداع طبقة قراءة الكفض (NSUserDefaults) لمنع التطبيق من استرجاع البصمة القديمة
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    // إذا حاول التطبيق استدعاء مفاتيح لها علاقة بالـ DeviceID أو الـ Token القديم، نقوم بتصفيرها
    if ([defaultName containsString:@"device"] || [defaultName containsString:@"udid"] || [defaultName containsString:@"uuid"] || [defaultName containsString:@"guid"]) {
        return nil;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    // منع حفظ معرف الجهاز القديم محلياً لكي يظل التطبيق في حالة "جهاز جديد" دائماً
    if ([defaultName containsString:@"device"] || [defaultName containsString:@"udid"] || [defaultName containsString:@"uuid"]) {
        return;
    }
    %orig;
}

%end
