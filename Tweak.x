#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// إخفاء مسار مكتبة الحقن والتويك عن فحص الـ dyld
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    const char *name = %orig(image_index);
    if (name != NULL) {
        NSString *imageStr = [NSString stringWithUTF8String:name];
        // إخفاء أي مسار يحتوي على مؤشرات الحقن أو التويكات الشائعة
        if ([imageStr containsString:@".dylib"] || [imageStr containsString:@"TweakLoader"] || [imageStr containsString:@"CydiaSubstrate"] || [imageStr containsString:@"MobileSubstrate"]) {
            return ""; 
        }
    }
    return name;
}

// تعطيل فحص الحماية والجلبريك المحلي بالكامل
%hook YMM__YX_SSJailbreakCheck

+ (int)filesExistCheck {
    return 0;
}

+ (int)cydiaCheck {
    return 0;
}

+ (int)inaccessibleFilesCheck {
    return 0;
}

+ (int)jailbroken {
    return 0;
}

+ (int)plistCheck {
    return 0;
}

+ (int)symbolicLinkCheck {
    return 0;
}

+ (int)urlCheck {
    return 0;
}

+ (id)runningProcesses {
    return nil;
}

%end
