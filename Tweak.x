#import <Foundation/Foundation.h>

%hook NSBundle

// 1. خداع معرف الحزمة الأساسي
- (NSString *)bundleIdentifier {
    if (self == [NSBundle mainBundle]) {
        return @"tel.pingme";
    }
    return %orig;
}

// 2. خداع مسار المجلد (Bundle Path)
- (NSString *)bundlePath {
    NSString *origPath = %orig;
    if (self == [NSBundle mainBundle]) {
        return [[origPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tel.pingme.app"];
    }
    return origPath;
}

// 3. خداع رابط المجلد (Bundle URL)
- (NSURL *)bundleURL {
    NSURL *origURL = %orig;
    if (self == [NSBundle mainBundle]) {
        NSString *origPath = [origURL path];
        NSString *newPath = [[origPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tel.pingme.app"];
        return [NSURL fileURLWithPath:newPath];
    }
    return origURL;
}

// 4. خداع قاموس المعلومات بالكامل (Info.plist Dictionary) لمنع أي قراءة مباشرة للبيانات
- (NSDictionary *)infoDictionary {
    NSDictionary *origDict = %orig;
    if (self == [NSBundle mainBundle] && origDict) {
        NSMutableDictionary *mutableDict = [origDict mutableCopy];
        mutableDict[@"CFBundleIdentifier"] = @"tel.pingme";
        mutableDict[@"CFBundleName"] = @"PingMe";
        mutableDict[@"CFBundleDisplayName"] = @"PingMe";
        return mutableDict;
    }
    return origDict;
}

// 5. خداع جلب أي مفتاح منفرد من الـ Info.plist
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (self == [NSBundle mainBundle]) {
        if ([key isEqualToString:@"CFBundleIdentifier"]) {
            return @"tel.pingme";
        }
        if ([key isEqualToString:@"CFBundleName"] || [key isEqualToString:@"CFBundleDisplayName"]) {
            return @"PingMe";
        }
    }
    return %orig;
}

// 6. خداع مسار الملف التنفيذي (Executable Path) لكي يطابق الاسم الأصلي
- (NSString *)executablePath {
    NSString *origPath = %orig;
    if (self == [NSBundle mainBundle]) {
        return [[origPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"PingMe"];
    }
    return origPath;
}

%end

// 7. خداع معلومات النظام والعمليات (NSProcessInfo) لمنع أي فحص خارجي لاسم العملية
%hook NSProcessInfo

- (NSString *)processName {
    return @"PingMe";
}

- (NSArray<NSString *> *)arguments {
    NSArray *origArgs = %orig;
    if ([origArgs count] > 0) {
        NSMutableArray *mutableArgs = [origArgs mutableCopy];
        // تنظيف أي أثر للمجلدات المزيفة في وسائط التشغيل إن وجدت
        return mutableArgs;
    }
    return origArgs;
}

%end
