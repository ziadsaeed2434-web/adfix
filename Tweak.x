#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

// دالة مسلّحة للبحث الذكي عن زر الإغلاق داخل الـ View الخاصة بالإعلان فقط
static void dismissAdView(UIView *view) {
    if (!view) return;
    
    for (UIView *subview in view.subviews) {
        // التحقق مما إذا كان الزر هو UIButton أو UIControl
        if ([subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UIControl class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            NSString *accessibilityLabel = button.accessibilityLabel;
            
            // مطابقة الكلمات الشائعة لزر الإغلاق
            if ([title isEqualToString:@"X"] || [title isEqualToString:@"✕"] || 
                [title isEqualToString:@"Close"] || [title isEqualToString:@"Fermer"] || 
                [accessibilityLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accessibilityLabel localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accessibilityLabel localizedCaseInsensitiveContainsString:@"exit"]) {
                
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
        
        // بحث تداخلي عميق ولكن بشكل آمن
        dismissAdView(subview);
    }
}

%hook UIViewController

// مراقبة عرض واجهات العرض (تحديد الإعلانات ونافذة الأبل ستور)
- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig;
    
    if (!viewControllerToPresent) return;

    // 1. معالجة نافذة الأبل ستور فور ظهورها (SKStoreProductViewController)
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [viewControllerToPresent dismissViewControllerAnimated:YES completion:nil];
        });
        return;
    }
    
    // 2. مراقبة الإعلانات التي تفتح كـ Modal وإعطاؤها مهلة قصيرة لعرض زر الإغلاق ثم الضغط عليه
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewControllerToPresent.view) {
            dismissAdView(viewControllerToPresent.view);
        }
    });
}

%end

// مراقبة العناصر الجديدة التي تضاف للشاشة لتغطية أي إعلانات داخلية (In-app Ads)
%hook UIView

- (void)didAddSubview:(UIView * )subview {
    %orig;
    
    // التحقق المباشر من الـ Subview الجديدة فقط لعدم التسبب بثقل في المعالج
    if (subview && [subview isKindOfClass:[UIView class]]) {
        // تأخير بسيط جداً للتأكد من اكتمال رسم عناصر الإعلان
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dismissAdView(subview);
        });
    }
}

%end

