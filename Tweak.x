#import <UIKit/UIKit.h>

// دالة للبحث عن زر الإغلاق، علامة الـ X، أو زر Continue والضغط عليها
void findAndDismissAd(UIView *view) {
    for (UIView *subview in view.subviews) {
        
        // التحقق مما إذا كان العنصر عبارة عن زر
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            CGRect frame = button.frame;
            
            // شروط الموقع: يجب أن يكون في الجزء العلوي من الشاشة (مثل الأماكن التي تظهر فيها أزرار الإعلانات)
            BOOL isTopArea = frame.origin.y < 150;
            
            // استخراج النص الموجود داخل الزر (إن وجد) للتحقق مما إذا كان زر Continue أو تخطي
            NSString *buttonTitle = [button titleForState:UIControlStateNormal];
            BOOL hasContinueText = buttonTitle && ([buttonTitle localizedCaseInsensitiveContainsString:@"Continue"] || 
                                                   [buttonTitle localizedCaseInsensitiveContainsString:@"Skip"] || 
                                                   [buttonTitle localizedCaseInsensitiveContainsString:@"إغلاق"]);
            
            // أو إذا كان زرًا صغيرًا في الزاوية (يمثل علامة X)
            BOOL isSmallXButton = (frame.size.width > 10 && frame.size.width < 70 && frame.size.height > 10 && frame.size.height < 60);
            
            if (isTopArea && (hasContinueText || isSmallXButton) && button.isHidden == NO && button.alpha > 0.5) {
                // محاكاة الضغط على الزر
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        
        // البحث بشكل متكرر داخل العناصر الفرعية
        if (subview.subviews.count > 0) {
            findAndDismissAd(subview);
        }
    }
}

// مراقبة الشاشة وتنفيذ الفحص بشكل دوري
%hook UIWindow

- (void)layoutSubviews {
    %orig;
    
    static NSTimeInterval lastCheck = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // فحص الشاشة كل نصف ثانية لتوفير استهلاك البطارية وسرعة الاستجابة
    if (now - lastCheck > 0.2) {
        lastCheck = now;
        findAndDismissAd(self);
    }
}

%end
