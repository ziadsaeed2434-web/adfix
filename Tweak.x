#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

// دالة محاكاة النقر
static void simulateTapOnView(UIView *view) {
    if (!view) return;
    
    // 1. إذا كان UIButton أو UIControl
    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)view;
        if (control.enabled && control.userInteractionEnabled) {
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
            [control sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    }
    
    // 2. إرسال Tap Gesture Recognizers إذا وجدت
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            // تنفيذ الـ target الخاص بالـ Gesture إن أمكن، أو إرسال الحدث للـ View
            [view.superview bringSubviewToFront:view];
        }
    }
    
    // 3. محاكاة نقرة مباشرة عبر الـ touches إن أمكن، أو الاعتماد على الـ UIControl أعلاه
}

// دالة بحث آمنة وشاملة لكل عناصر الإغلاق المحتملة
static void safeDismissAd(UIView *view) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;
    
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if (!subview || subview.hidden || subview.alpha < 0.01) continue;
        
        BOOL isCloseElement = NO;
        
        // أ) التحقق إذا كان UIButton أو UILabel أو UIImageView يحتوي على نص إغلاق
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            NSString *accLabel = button.accessibilityLabel;
            NSString *accId = button.accessibilityIdentifier;
            
            if ([title isEqualToString:@"X"] || [title isEqualToString:@"✕"] || [title isEqualToString:@"×"] ||
                [title localizedCaseInsensitiveContainsString:@"close"] || [title localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"close"] || [accLabel localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] || [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        } 
        else if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if ([text isEqualToString:@"X"] || [text isEqualToString:@"✕"] || [text isEqualToString:@"×"] ||
                [text localizedCaseInsensitiveContainsString:@"close"] || [text localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        }
        
        // ب) التحقق من الـ Accessibility للـ Views بشكل عام
        if (!isCloseElement) {
            NSString *accLabel = subview.accessibilityLabel;
            NSString *accId = subview.accessibilityIdentifier;
            if ([accLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accLabel localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"skip"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] ||
                [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        }
        
        if (isCloseElement) {
            if (subview.userInteractionEnabled) {
                simulateTapOnView(subview);
                return;
            }
        }
        
        // استدعاء تداخلي آمن للأبناء
        safeDismissAd(subview);
    }
}

%hook UIViewController

- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig;
    
    if (!viewControllerToPresent) return;

    // 1. معالجة صفحة الأبل ستور
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (viewControllerToPresent && !viewControllerToPresent.isBeingDismissed) {
                [viewControllerToPresent dismissViewControllerAnimated:YES completion:nil];
            }
        });
        return;
    }
    
    // 2. فحص الإعلانات على دفعات زمنية
    for (double delay = 1.0; delay <= 3.5; delay += 1.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (viewControllerToPresent && viewControllerToPresent.view && !viewControllerToPresent.isBeingDismissed) {
                safeDismissAd(viewControllerToPresent.view);
            }
        });
    }
}

%end

%hook UIView

- (void)didAddSubview:(UIView * )subview {
    %orig;
    
    if (!subview) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (subview && subview.superview) {
            safeDismissAd(subview);
        }
    });
}

%end
