#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <WebKit/WebKit.h>

// دالة فحص وتنفيد JavaScript فورية لإعلانات الويب والتفاعلية (تضغط على كل أزرار الويب المتعددة)
static void immediateDismissWebAds(UIView *view) {
    if (!view) return;
    
    if ([view isKindOfClass:[WKWebView class]]) {
        WKWebView *webView = (WKWebView *)view;
        NSString *jsCloseScript = 
        @"(function() {"
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
        "var closeBtns = document.querySelectorAll('[class*=\"close\"], [id*=\"close\"], [class*=\"skip\"], [id*=\"skip\"], .ads-close, #close-btn');"
        "closeBtns.forEach(function(btn) { btn.click(); });"
        "})();";
        
        [webView evaluateJavaScript:jsCloseScript completionHandler:nil];
    }
    
    for (UIView *subview in view.subviews) {
        immediateDismissWebAds(subview);
    }
}

// دالة محاكاة النقر الفوري
static void simulateImmediateTap(UIView *view) {
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

// دالة البحث والإغلاق الفوري التي لا تتوقف وتضغط على كل الأزرار الموجودة
static void checkAndDismissInstantly(UIView *view) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;
    
    // فحص محتوى الويب فوراً لكل الـ WebViews الموجودة
    immediateDismissWebAds(view);
    
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
        
        // إذا وجد عنصر إغلاق، يضغط عليه ولا يتوقف (تمت إزالة الـ return لكي يكمل على باقي الأزرار)
        if (isCloseElement) {
            if (subview.userInteractionEnabled) {
                simulateImmediateTap(subview);
            }
        }
        
        // تفتيش تداخلي فوري لكل العناصر الفرعية بلا استثناء
        checkAndDismissInstantly(subview);
    }
}

%hook UIViewController

- (void)presentViewController:(UIViewController * )viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[SKStoreProductViewController class]]) {
        return; 
    }
    
    %orig;
    
    if (!viewControllerToPresent) return;

    // فحص فوري ولحظي للشاشة فور ظهورها للتعامل مع أي أزرار مبكرة
    if (viewControllerToPresent.view) {
        checkAndDismissInstantly(viewControllerToPresent.view);
    }
}

%end

%hook UIView

- (void)didAddSubview:(UIView * )subview {
    %orig;
    
    if (!subview) return;
    
    // فحص لحظي وفوري لكل العناصر التي يتم إضافتها (يضمن ضغط أي X أول أو ثانٍ بمجرد ظهوره)
    checkAndDismissInstantly(subview);
}

%end
