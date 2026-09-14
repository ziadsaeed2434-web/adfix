#import <UIKit/UIKit.h>

// دالة متقدمة للبحث عن الأزرار، النصوص، وعناصر التفاعل وضغطها فوراً
void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        // 1. فحص عناصر الـ UIControl بشكل عام (يشمل الأزرار وكل ما يقبل الضغط)
        if ([subview isKindOfClass:[UIControl class]]) {
            UIControl *control = (UIControl *)subview; // تم تصحيح القوس هنا
            CGRect frame = control.frame;
            
            // توسيع نطاق البحث ليشمل الأجزاء العليا بمرونة أكبر
            BOOL isTopArea = frame.origin.y < 200;
            BOOL isSmallXButton = (frame.size.width > 10 && frame.size.width < 80 && frame.size.height > 10 && frame.size.height < 80);
            
            if (isTopArea && isSmallXButton && !control.isHidden && control.alpha > 0.3) {
                [control sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        // 2. فحص الأزرار والتحقق من النصوص بداخلها أو العناوين المرتبطة
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            if (title && ([title localizedCaseInsensitiveContainsString:@"Continue"] || 
                          [title localizedCaseInsensitiveContainsString:@"Skip"] || 
                          [title localizedCaseInsensitiveContainsString:@"Loading ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"Watch Ad"] ||
                          [title localizedCaseInsensitiveContainsString:@"إغلاق"])) {
                
                button.enabled = YES;
                button.userInteractionEnabled = YES;
                button.alpha = 1.0;
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        // 3. أحياناً يكون النص داخل UILabel فوق زر تفاعلي، نقوم بفحص النصوص أيضاً
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            
            if (text && ([text localizedCaseInsensitiveContainsString:@"Continue"] || 
                         [text localizedCaseInsensitiveContainsString:@"Skip"])) {
                // محاكاة الضغط على العنصر الأب (SuperView) الذي يحمل تفاعل اللمس
                if (label.superview && [label.superview isKindOfClass:[UIControl class]]) {
                    [(UIControl *)label.superview sendActionsForControlEvents:UIControlEventTouchUpInside];
                    break;
                }
            }
        }
        
        // البحث بشكل متكرر داخل العناصر الفرعية
        if (subview.subviews.count > 0) {
            findAndDismissAd(subview);
        }
    }
}

%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // السرعة القصوى 0.1 ثانية
    if (now - lastCheck > 0.1) {
        lastCheck = now;
        findAndDismissAd(self);
    }
}

%end
