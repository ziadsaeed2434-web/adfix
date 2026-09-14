#import <UIKit/UIKit.h>

void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        // 1. الأولوية الأولى: البحث عن أزرار الاستمرار والمكافأة (Continue / Skip / Watch Ad) لضمان أخذ الجائزة وعدم الخروج
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            if (title && ([title localizedCaseInsensitiveContainsString:@"Continue"] || 
                          [title localizedCaseInsensitiveContainsString:@"Skip"] || 
                          [title localizedCaseInsensitiveContainsString:@"Watch Ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"Loading ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"إغلاق"])) {
                
                if (button.alpha > 0.3 && !button.isHidden) {
                    button.enabled = YES;
                    button.userInteractionEnabled = YES;
                    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                    return; // الخروج من الدالة بمجرد الضغط لضمان عدم تداخل الأوامر
                }
            }
        }
        
        // 2. الأولوية الثانية: البحث عن زر الـ (X) بحذر شديد وفي الزاوية العليا المحددة فقط
        CGRect frame = subview.frame;
        BOOL isTopArea = frame.origin.y < 120; // تقليل النطاق قليلاً ليكون أكثر دقة في الزاوية العليا
        BOOL isTopRightOrLeft = (frame.origin.x < 70 || frame.origin.x > (view.bounds.size.width - 70));
        BOOL isSmallSize = (frame.size.width > 15 && frame.size.width < 60 && frame.size.height > 15 && frame.size.height < 60);
        
        if (isTopArea && isTopRightOrLeft && isSmallSize && !subview.isHidden && subview.alpha > 0.5) {
            if ([subview isKindOfClass:[UIControl class]]) {
                [(UIControl *)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
            if ([subview isKindOfClass:[UIButton class]]) {
                ((UIButton *)subview).enabled = YES;
                [((UIButton *)subview) sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
        
        // البحث التلقائي المستمر داخل العناصر الفرعية
        if (subview.subviews.count > 0) {
            findAndDismissAd(subview);
        }
    }
}

// تنفيذ الفحص كل 0.2 ثانية
%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if (now - lastCheck > 0.2) {
        lastCheck = now;
        findAndDismissAd(self);
    }
}

%end
