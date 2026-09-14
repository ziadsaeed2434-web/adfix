#import <UIKit/UIKit.h>

// دالة فورية للبحث والضغط بلا انتظار أو فحص زمني
void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        CGRect frame = subview.frame;
        
        // 1. فحص زر الـ X أو علامات الإغلاق في الزوايا العليا فوراً
        BOOL isTopArea = frame.origin.y < 220;
        BOOL isTopRightOrLeft = (frame.origin.x < 100 || frame.origin.x > (view.bounds.size.width - 100));
        BOOL isSmallSize = (frame.size.width > 10 && frame.size.width < 75 && frame.size.height > 10 && frame.size.height < 75);
        
        if (isTopArea && isTopRightOrLeft && isSmallSize && !subview.isHidden && subview.alpha > 0.2) {
            if ([subview isKindOfClass:[UIControl class]]) {
                [(UIControl *)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
            if ([subview isKindOfClass:[UIButton class]]) {
                ((UIButton *)subview).enabled = YES;
                [((UIButton *)subview) sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        // 2. فحص أزرار Continue و Skip و Loading ad وضغطها فوراً بلا شروط زمنية
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            if (title && ([title localizedCaseInsensitiveContainsString:@"Continue"] || 
                          [title localizedCaseInsensitiveContainsString:@"Skip"] || 
                          [title localizedCaseInsensitiveContainsString:@"Watch Ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"Loading ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"إغلاق"])) {
                
                button.enabled = YES;
                button.userInteractionEnabled = YES;
                button.alpha = 1.0;
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        // البحث التلقائي المستمر داخل العناصر الفرعية
        if (subview.subviews.count > 0) {
            findAndDismissAd(subview);
        }
    }
}

// تنفيذ مباشر مع كل حدث تحديث للشاشة دون أي شروط وقت أو تأخير
%hook UIWindow

- (void)layoutSubviews {
    %orig;
    // التنفيذ الفوري بلا انتظار
    findAndDismissAd(self);
}

%end
