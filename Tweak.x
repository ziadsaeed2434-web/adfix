#import <UIKit/UIKit.h>

%hook APMETaskManager

// خداع دالة حساب الوقت المنقضي وجعلها تعيد دائماً قيمة ضخمة تعني أن الوقت قد انقضى بالكامل (أكثر من 6 أو 7 ساعات)
- (CGFloat)fetchTimeFromLastSuccessfulTimestamp:(CGFloat)arg1 lastFailedTimestamp:(CGFloat)arg2 {
    // إرجاع قيمة زمنية كبيرة تفيد بانقضاء مدة الانتظار بالكامل فوراً
    return 99999.0;
}

// التأكد من أن حالة الجلب الأولية مفعلة دائماً
- (BOOL)hasMadeInitialFetch {
    return YES;
}

// تجاوز إعادة تعيين المؤقتات
- (void)reset {
    %orig();
}

%end
