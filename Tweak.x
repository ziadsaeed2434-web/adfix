#import <UIKit/UIKit.h>

// دالة مساعدة للبحث والضغط داخل العناصر
static void searchAndTapConsent(UIView *view) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *title = [btn titleForState:UIControlStateNormal];
            if ([title isEqualToString:@"Consent"]) {
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
        if (subview.subviews.count > 0) {
            searchAndTapConsent(subview);
        }
    }
}

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    // تنفيذ البحث بعد التأكد من ظهور النافذة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        searchAndTapConsent(self);
    });
}

%end
