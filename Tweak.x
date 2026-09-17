#import <UIKit/UIKit.h>

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [self checkAndHideConsentWindow:self];
}

- (void)layoutSubviews {
    %orig;
    [self checkAndHideConsentWindow:self];
}

%new
- (void)checkAndHideConsentWindow:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            // فحص النصوص الموجودة في صورتك لإخفاء النافذة فوراً
            if ([label.text containsString:@"personal data"] || 
                [label.text containsString:@"consent"] || 
                [label.text containsString:@"advertising and content"]) {
                
                // إخفاء النافذة بالكامل من على الشاشة
                self.hidden = YES;
                self.alpha = 0.0;
                [self setUserInteractionEnabled:NO];
                break;
            }
        }
        [self checkAndHideConsentWindow:subview];
    }
}

%end
