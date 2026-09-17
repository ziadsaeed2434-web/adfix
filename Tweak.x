#import <UIKit/UIKit.h>

// تصريح مسبق للدالة لتجنب أخطاء المترجم
@interface UIWindow (ConsentHider)
- (void)checkAndHideConsentWindow:(UIView *)view;
@end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [self checkAndHideConsentWindow:self];
}

- (void)layoutSubviews {
    %orig;
    [self checkAndHideConsentWindow:self];
}

%end

%hook UIWindow

%new
- (void)checkAndHideConsentWindow:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text containsString:@"personal data"] || 
                [label.text containsString:@"consent"] || 
                [label.text containsString:@"advertising and content"]) {
                
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
