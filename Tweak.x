#import <UIKit/UIKit.h>

// دالة للبحث والضغط
void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        CGRect frame = subview.frame;
        
        // 1. فحص زر الـ X أو علامات الإغلاق في الزوايا العليا
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
        
        // 2. فحص أزرار Continue و Skip و Loading ad وضغطها
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

// تنفيذ الفحص كل 0.2 ثانية مع كل تحديث للشاشة
%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // تنفيذ الفحص كل 0.2 ثانية
    if (now - lastCheck > 0.2) {
        lastCheck = now;
        findAndDismissAd(self);
    }
}

%end
