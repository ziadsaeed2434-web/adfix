#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

// دالة بحث آمنة جداً ومحمية ضد الكرش
static void safeDismissAd(UIView *view) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;
    
    // استخدام حلقة آمنة لتفادي التعديل المباشر أثناء التكرار
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if (!subview) continue;
        
        // التحقق مما إذا كان الزر هو UIButton
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            NSString *accessibilityLabel = button.accessibilityLabel;
            
            if ([title isEqualToString:@"X"] || [title isEqualToString:@"✕"] || 
                [title isEqualToString:@"Close"] || [title isEqualToString:@"Fermer"] ||
                [accessibilityLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accessibilityLabel localizedCaseInsensitiveContainsString:@"dismiss"]) {
                
                // التأكد من أن الزر مفعل ويمكن الضغط عليه
                if (button.enabled && button.userInteractionEnabled) {
                    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                    return;
                }
            }
        }
        
        // استدعاء تداخلي آمن
        safeDismissAd(subview);
    }
}

%hook UIViewController

- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig;
    
    if (!viewControllerToPresent) return;

    // 1. معالجة صفحة الأبل ستور بشكل آمن تماماً
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (viewControllerToPresent && !viewControllerToPresent.isBeingDismissed) {
                [viewControllerToPresent dismissViewControllerAnimated:YES completion:nil];
            }
        });
        return;
    }
    
    // 2. معالجة الإعلانات بمهلة آمنة تضمن عدم الانهيار
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewControllerToPresent && viewControllerToPresent.view && !viewControllerToPresent.isBeingDismissed) {
            safeDismissAd(viewControllerToPresent.view);
        }
    });
}

%end

%hook UIView

- (void)didAddSubview:(UIView * )subview {
    %orig;
    
    if (!subview) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // التأكد من أن الـ view ما زال موجوداً في الذاكرة ولم يتم حذفه
        if (subview && subview.superview) {
            safeDismissAd(subview);
        }
    });
}

%end
