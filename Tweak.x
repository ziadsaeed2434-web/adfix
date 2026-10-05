#substrate
#import <objc/runtime.h>

// استهداف الكلاس الأساسي الخاص بالـ ViewModel
%hook TempNumber_ShakeViewModel

// اعتراض دالة تهيئة الكائن (Init) لتعديل المتغيرات أول بأول
- (id)init {
    id self = %orig;
    if (self) {
        // الوصول المباشر لمتغير _currentShakes وتصفيره
        Ivar currentShakesIvar = class_getInstanceVariable(object_getClass(self), "_currentShakes");
        if (currentShakesIvar) {
            NSInteger *val = (NSInteger *)((char *)self + ivar_getOffset(currentShakesIvar));
            *val = 0;
        }
        
        // رفع الحد الأقصى _maxDailyShakes لضمان عدم توقف الزر أبداً
        Ivar maxShakesIvar = class_getInstanceVariable(object_getClass(self), "_maxDailyShakes");
        if (maxShakesIvar) {
            NSInteger *maxVal = (NSInteger *)((char *)self + ivar_getOffset(maxShakesIvar));
            *maxVal = 99999;
        }
    }
    return self;
}

%end
