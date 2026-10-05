#import <objc/runtime.h>

@interface TempNumber_ShakeViewModel : NSObject
@end

%hook TempNumber_ShakeViewModel

- (id)init {
    id origSelf = %orig;
    if (origSelf) {
        Class cls = object_getClass(origSelf);
        
        // 1. تصفير عدد الهزات الحالية _currentShakes عند الإزاحة الصحيحة
        Ivar currentShakesIvar = class_getInstanceVariable(cls, "_currentShakes");
        if (currentShakesIvar) {
            long *val = (long *)((__bridge void *)origSelf + ivar_getOffset(currentShakesIvar));
            *val = 0;
        }
        
        // 2. رفع الحد الأقصى _maxDailyShakes لمنع توقف الزر
        Ivar maxShakesIvar = class_getInstanceVariable(cls, "_maxDailyShakes");
        if (maxShakesIvar) {
            long *maxVal = (long *)((__bridge void *)origSelf + ivar_getOffset(maxShakesIvar));
            *maxVal = 99999;
        }
    }
    return origSelf;
}

%end
