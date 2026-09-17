#import <UIKit/UIKit.h>

// تعريف مسبق للدالة لتجنب أخطاء المترجم
@interface UIViewController (ConsentHelper)
- (BOOL)containsConsentText:(UIView *)view;
@end

%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    
    // التحقق من محتويات الواجهة المراد عرضها لمنع نافذة الموافقة من الظهور نهائياً
    [viewControllerToPresent loadViewIfNeeded];
    if ([viewControllerToPresent containsConsentText:viewControllerToPresent.view]) {
        // إلغاء عرض النافذة تماماً
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%end

%hook UIViewController

%new
- (BOOL)containsConsentText:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text containsString:@"personal data"] || 
                [label.text containsString:@"consent"] || 
                [label.text containsString:@"advertising and content"]) {
                return YES;
            }
        }
        if ([subview.subviews count] > 0) {
            if ([self containsConsentText:subview]) {
                return YES;
            }
        }
    }
    return NO;
}

%end
