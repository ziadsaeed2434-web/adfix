#import <UIKit/UIKit.h>

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    // فحص النافذة فور ظهورها على الشاشة للبحث عن زر الموافقة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self searchAndTapConsent:self];
    });
}

%new
- (void)searchAndTapConsent:(UIView *)view {
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
            [self searchAndTapConsent:subview];
        }
    }
}

%end
