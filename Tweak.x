#import <UIKit/UIKit.h>

// استهداف الفئة المسؤولة عن إدارة المهام
%hook APMETaskManager

// إجبار خاصية الجلب الأولي على أن تكون صحيحة
- (BOOL)hasMadeInitialFetch {
    return YES;
}

- (void)setHasMadeInitialFetch:(BOOL)arg1 {
    %orig(YES);
}

// اعتراض دالة بدء مدير المهام والتأكد من استدعائها وإجبارها على جلب المهام
- (void)startTaskManager {
    %orig;
    // يمكنك إضافة أي استدعاء إضافي هنا إذا لزم الأمر
}

- (void)fetchExperiments {
    // اجبار جلب المهام والإعلانات على العمل حتى لو فشل التحقق من الشهادة
    %orig;
}

%end
