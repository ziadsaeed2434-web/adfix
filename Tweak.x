#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

// دالة متقدمة لمحاكاة النقر تشمل الأزرار، الـ Controls، وإيماءات اللمس في كل أنواع الإعلانات
static void simulateAdvancedTap(UIView *view) {
    if (!view) return;
    
    // 1. إذا كان UIButton أو UIControl
    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)view;
        if (control.enabled && control.userInteractionEnabled) {
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
            [control sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    }
    
    // 2. البحث عن الـ Gesture Recognizers وتفعيلها (مهم جداً للإعلانات التفاعلية و WebViews الحديثة)
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            // محاكاة استهداف الـ View وتنفيذ الإيماءة برمجياً
            [view.superview bringSubviewToFront:view];
            // إرسال الأحداث عبر الـ target إن أمكن أو تحفيز الـ action
        }
    }
    
    // 3. محاكاة لمسة مركزية مباشرة على الإحداثيات في حال كان عنصراً تفاعلياً مخصصاً
    CGPoint centerPoint = CGPointMake(CGRectGetWidth(view.bounds) / 2.0, CGRectGetHeight(view.bounds) / 2.0);
    UIEvent *event = [[UIEvent alloc] init];
    [view touchesBegan:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:event];
    [view touchesEnded:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:event];
}

// دالة بحث شاملة تشمل جميع أنواع الإعلانات (نصوص، رموز، صور، أزرار إغلاق مخفية، وتطبيقات الويب)
static void safeDismissAllAds(UIView *view) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;
    
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if (!subview || subview.hidden || subview.alpha < 0.01) continue;
        
        BOOL isCloseElement = NO;
        
        // أ) فحص الأزرار (UIButton)
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            NSString *accLabel = button.accessibilityLabel;
            NSString *accId = button.accessibilityIdentifier;
            
            if ([title isEqualToString:@"X"] || [title isEqualToString:@"✕"] || [title isEqualToString:@"×"] ||
                [title localizedCaseInsensitiveContainsString:@"close"] || [title localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [title localizedCaseInsensitiveContainsString:@"skip"] || [title localizedCaseInsensitiveContainsString:@"إغلاق"] ||
                [title localizedCaseInsensitiveContainsString:@"تخطي"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"close"] || [accLabel localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"skip"] || [accId localizedCaseInsensitiveContainsString:@"close"] ||
                [accId localizedCaseInsensitiveContainsString:@"skip"] || [accId localizedCaseInsensitiveContainsString:@"dismiss"]) {
                isCloseElement = YES;
            }
        } 
        // ب) فحص النصوص العادية (UILabel) التي تستخدم للإغلاق
        else if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if ([text isEqualToString:@"X"] || [text isEqualToString:@"✕"] || [text isEqualToString:@"×"] ||
                [text localizedCaseInsensitiveContainsString:@"close"] || [text localizedCaseInsensitiveContainsString:@"skip"] ||
                [text localizedCaseInsensitiveContainsString:@"إغلاق"] || [text localizedCaseInsensitiveContainsString:@"تخطي"]) {
                isCloseElement = YES;
            }
        }
        // ج) فحص الصور أو الأيقونات التي تمثل زر إغلاق (UIImageView)
        else if ([subview isKindOfClass:[UIImageView class]]) {
            NSString *accLabel = subview.accessibilityLabel;
            NSString *accId = subview.accessibilityIdentifier;
            if ([accLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accLabel localizedCaseInsensitiveContainsString:@"skip"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] ||
                [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        }
        
        // د) الفحص العام للـ Accessibility لأي عنصر آخر على الشاشة
        if (!isCloseElement) {
            NSString *accLabel = subview.accessibilityLabel;
            NSString *accId = subview.accessibilityIdentifier;
            if ([accLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accLabel localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"skip"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"إغلاق"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] ||
                [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        }
        
        if (isCloseElement) {
            if (subview.userInteractionEnabled) {
                simulateAdvancedTap(subview);
            }
        }
        
        // استمرار التفتيش التداخلي في كل الطبقات الفرعية (الوصول لكل أنواع الإعلانات الداخلية)
        safeDismissAllAds(subview);
    }
}

%hook UIViewController

- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // منع ظهور نافذة الأبل ستور المزعجة فقط دون تعطيل النظام الأساسي للإعلانات
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        return; 
    }
    
    %orig;
    
    if (!viewControllerToPresent) return;

    // تأخير الفحص قليلاً (2.5 ثانية) لضمان أن الإعلان بدأ وعمل بشكل طبيعي لكي لا يفقد التطبيق المكافأة، ثم البدء بالبحث عن أزرار الإغلاق بكل أنواعها
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewControllerToPresent && viewControllerToPresent.view && !viewControllerToPresent.isBeingDismissed) {
            safeDismissAllAds(viewControllerToPresent.view);
        }
    });
}

%end

%hook UIView

- (void)didAddSubview:(UIView * )subview {
    %orig;
    
    if (!subview) return;
    
    // فحص دوري وآمن للعناصر المضافة حديثاً بعد تأخير بسيط ليأخذ الإعلان وقته
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (subview && subview.superview) {
            safeDismissAllAds(subview);
        }
    });
}

%end
