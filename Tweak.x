#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <WebKit/WebKit.h>

// دالة متقدمة لحقن وتنفيد جافا سكريبت لإغلاق إعلانات الويب والتفاعلية تلقائياً
static void injectJavaScriptToDismissWebAds(UIView *view) {
    if (!view) return;
    
    // إذا كان العنصر عبارة عن WKWebView، نقوم بحقن سكريبت يبحث عن جميع أنواع أزرار الإغلاق والتخطي في الويب وينقر عليها
    if ([view isKindOfClass:[WKWebView class]]) {
        WKWebView *webView = (WKWebView *)view;
        NSString *jsCloseScript = 
        @"(function() {"
        // البحث عن الـ Selectors الشائعة لأزرار الإغلاق والتخطي في الإعلانات التفاعلية والويب
        "var selectors = ['button', 'div', 'span', 'a', 'img', 'svg'];"
        "for (var i = 0; i < selectors.length; i++) {"
        "  var elements = document.querySelectorAll(selectors[i]);"
        "  for (var j = 0; j < elements.length; j++) {"
        "    var el = elements[j];"
        "    var text = el.innerText || el.textContent || '';"
        "    var aria = el.getAttribute('aria-label') || '';"
        "    var cls = el.className || '';"
        "    var id = el.id || '';"
        "    var combined = (text + ' ' + aria + ' ' + cls + ' ' + id).toLowerCase();"
        "    if (combined.includes('close') || combined.includes('dismiss') || combined.includes('skip') || "
        "        combined.includes('إغلاق') || combined.includes('تخطي') || combined.includes('x') || "
        "        el.id === 'close_button' || el.className.indexOf('close') !== -1 || el.className.indexOf('skip') !== -1) {"
        "       el.click();"
        "    }"
        "  } "
        "}"
        // محاولة إغلاق أي إطار فيديو تفاعلي أو عناصر مخفية
        "var closeBtns = document.querySelectorAll('[class*=\"close\"], [id*=\"close\"], [class*=\"skip\"], [id*=\"skip\"], .ads-close, #close-btn');"
        "closeBtns.forEach(function(btn) { btn.click(); });"
        "})();";
        
        [webView evaluateJavaScript:jsCloseScript completionHandler:nil];
    }
    
    // البحث التداخلي في باقي الـ Subviews للوصول لأي WebView داخلي
    for (UIView *subview in view.subviews) {
        injectJavaScriptToDismissWebAds(subview);
    }
}

// دالة محاكاة النقر العادية للعناصر التقليدية
static void simulateAdvancedTap(UIView *view) {
    if (!view) return;
    
    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)view;
        if (control.enabled && control.userInteractionEnabled) {
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
            [control sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    }
    
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            [view.superview bringSubviewToFront:view];
        }
    }
}

// دالة الفحص الشاملة (تدمج الفحص العادي + فحص الويب التفاعلي)
static void safeDismissAllAds(UIView *view) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;
    
    // أولاً: حقن كود الويب لإغلاق الإعلانات التفاعلية ومحتويات الـ WebView
    injectJavaScriptToDismissWebAds(view);
    
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if (!subview || subview.hidden || subview.alpha < 0.01) continue;
        
        BOOL isCloseElement = NO;
        
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            NSString *accLabel = button.accessibilityLabel;
            NSString *accId = button.accessibilityIdentifier;
            
            if ([title isEqualToString:@"X"] || [title isEqualToString:@"✕"] || [title isEqualToString:@"×"] ||
                [title localizedCaseInsensitiveContainsString:@"close"] || [title localizedCaseInsensitiveContainsString:@"dismiss"] ||
                [title localizedCaseInsensitiveContainsString:@"skip"] || [title localizedCaseInsensitiveContainsString:@"إغلاق"] ||
                [title localizedCaseInsensitiveContainsString:@"تخطي"] ||
                [accLabel localizedCaseInsensitiveContainsString:@"close"] || [accLabel localizedCaseInsensitiveContainsString:@"skip"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] || [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        } 
        else if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if ([text isEqualToString:@"X"] || [text isEqualToString:@"✕"] || [text isEqualToString:@"×"] ||
                [text localizedCaseInsensitiveContainsString:@"close"] || [text localizedCaseInsensitiveContainsString:@"skip"] ||
                [text localizedCaseInsensitiveContainsString:@"إغلاق"] || [text localizedCaseInsensitiveContainsString:@"تخطي"]) {
                isCloseElement = YES;
            }
        }
        else if ([subview isKindOfClass:[UIImageView class]] || [subview isKindOfClass:[UIControl class]]) {
            NSString *accLabel = subview.accessibilityLabel;
            NSString *accId = subview.accessibilityIdentifier;
            if ([accLabel localizedCaseInsensitiveContainsString:@"close"] || 
                [accLabel localizedCaseInsensitiveContainsString:@"skip"] ||
                [accId localizedCaseInsensitiveContainsString:@"close"] ||
                [accId localizedCaseInsensitiveContainsString:@"skip"]) {
                isCloseElement = YES;
            }
        }
        
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
        
        safeDismissAllAds(subview);
    }
}

%hook UIViewController

- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        return; 
    }
    
    %orig;
    
    if (!viewControllerToPresent) return;

    // فحص دوري متكرر (عند الثانية 2.0 و 4.0 و 6.0) لضمان تغطية الإعلانات التفاعلية الطويلة التي تتأخر في ظهور أزرار الإغلاق
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewControllerToPresent && viewControllerToPresent.view && !viewControllerToPresent.isBeingDismissed) {
            safeDismissAllAds(viewControllerToPresent.view);
        }
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewControllerToPresent && viewControllerToPresent.view && !viewControllerToPresent.isBeingDismissed) {
            safeDismissAllAds(viewControllerToPresent.view);
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (subview && subview.superview) {
            safeDismissAllAds(subview);
        }
    });
}

%end
