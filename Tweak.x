#import <UIKit/UIKit.h>
#import <sys/utsname.h>

// 1. خداع معلومات الجهاز الأساسية وطراز اللوحة الأم
%hook UIDevice

- (NSString *)model {
    return @"iPhone";
}

- (NSString *)localizedModel {
    return @"iPhone";
}

- (NSString *)systemName {
    return @"iOS";
}

- (NSString *)systemVersion {
    // تعيين الإصدار إلى القيمة المطلوبة
    return @"26.6.1"; 
}

- (NSString *)name {
    return @"iPhone 15 Pro Max";
}

%end

// 2. خداع الـ UTSNAME لتغيير رمز الجهاز الداخلي إلى آيفون 15 برو ماكس (iPhone16,2)
%hookf(int, uname, struct utsname *name) {
    int result = %orig(name);
    if (result == 0 && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return result;
}

// 3. خداع معلومات المعالجة وإصدار النظام والذاكرة العشوائية (8 جيجابايت)
%hook NSProcessInfo

- (unsigned long long)physicalMemory {
    // 8 جيجابايت بالبايت
    return 8589934592ULL;
}

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSOperatingSystemVersion version;
    version.majorVersion = 26;
    version.minorVersion = 6;
    version.patchVersion = 1;
    return version;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    return YES;
}

%end
