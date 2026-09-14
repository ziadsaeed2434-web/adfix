#import <UIKit/UIKit.h>

// دالة للبحث عن زر الإغلاق أو علامة الـ X والضغط عليها
void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        // التحقق مما إذا كان الزر عبارة عن زر إغلاق إعلان بناءً على حجمه وموقعه في الزوايا العليا
        if ([subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UIControl class]]) {
            CGRect frame = subview.frame;
            
            // أزرار الإغلاق عادة تكون مربعة وصغيرة (أقل من 50x50 بكسل) وتوجد في الأجزاء العليا من الشاشة
            BOOL isTopArea = frame.origin.y < 150;
            BOOL isSmallSize = frame.size.width > 10 && frame.size.width < 60 && frame.size.height > 10 && frame.size.height < 60;
            
            if (isTopArea && isSmallSize && subview.isHidden == NO && subview.alpha > 0.5) {
                // محاكاة الضغط على زر الإغلاق
                if ([subview isKindOfClass:[UIButton class]]) {
                    [(UIButton *)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
                } else {
                    [(UIControl *)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
                }
                break;
            }
        }
        
        // البحث بشكل متكرر داخل الـ Subviews
        if (subview.subviews.count > 0) {
            findAndDismissAd(subview);
        }
    }
}

// مراقبة تحديثات الشاشة بانتظام للبحث عن زر الإغلاق فور ظهوره
%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    // تنفيذ الفحص بشكل آمن لتفادي الضغط المستمر غير الضروري
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if (now - lastCheck > 0.5) { // يفحص الشاشة كل نصف ثانية
        lastCheck = now;
        findAndDismissAd(self);
    }
}

%end
