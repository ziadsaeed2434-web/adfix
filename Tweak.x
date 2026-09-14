#import <UIKit/UIKit.h>

void bypassAndClickAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        if ([subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UIControl class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            // 1. تفعيل زر التحميل أو أزرار المشاهدة والتخطي قسراً والضغط عليها فوراً
            if (title && ([title localizedCaseInsensitiveContainsString:@"Loading ad"] || 
                          [title localizedCaseInsensitiveContainsString:@"Watch Ad & Earn"] ||
                          [title localizedCaseInsensitiveContainsString:@"Continue"] ||
                          [title localizedCaseInsensitiveContainsString:@"Skip"])) {
                
                button.enabled = YES;
                button.userInteractionEnabled = YES;
                button.alpha = 1.0;
                
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
            
            // 2. البحث عن علامة الإغلاق العادية (X) في الزوايا العليا
            CGRect frame = button.frame;
            if (frame.origin.y < 150 && frame.size.width > 10 && frame.size.width < 60 && frame.size.height > 10 && frame.size.height < 60) {
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        if (subview.subviews.count > 0) {
            bypassAndClickAd(subview);
        }
    }
}

%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // تم تعديل سرعة الفحص لتصبح كل 0.1 ثانية لأقصى سرعة ممكنة
    if (now - lastCheck > 0.1) {
        lastCheck = now;
        bypassAndClickAd(self);
    }
}

%end
