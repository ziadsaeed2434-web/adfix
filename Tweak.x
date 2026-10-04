#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// دالة جافا سكريبت ذكية للبحث والضغط على العناصر داخل صفحات الويب (WKWebView)
static void injectJavaScriptToHandleWebElements(UIView *view, NSString *targetText) {
    if (!view) return;
    
    if ([view isKindOfClass:[WKWebView class]]) {
        WKWebView *webView = (WKWebView *)view;
        NSString *jsScript = [NSString stringWithFormat:
        @"(function() {"
        "  var selectors = ['button', 'div', 'span', 'a', 'img', 'svg', 'input'];"
        "  for (var i = 0; i < selectors.length; i++) {"
        "    var elements = document.querySelectorAll(selectors[i]);"
        "    for (var j = 0; j < elements.length; j++) {"
        "      var el = elements[j];"
        "      var text = (el.innerText || el.textContent || '').trim().toLowerCase();"
        "      var aria = (el.getAttribute('aria-label') || '').toLowerCase();"
        "      var cls = (el.className || '').toLowerCase();"
        "      var target = '%@'.toLowerCase();"
        "      if (text.includes(target) || aria.includes(target) || cls.includes(target)) {"
        "         el.click();"
        "      }"
        "    }"
        "  }"
        "})();", targetText];
        
        [webView evaluateJavaScript:jsScript completionHandler:nil];
    }
    
    for (UIView *subview in view.subviews) {
        injectJavaScriptToHandleWebElements(subview, targetText);
    }
}

// دالة متقدمة للبحث عن العناصر في واجهات التطبيق (SwiftUI / UIKit)
static UIView *findViewByTitleOrLabel(UIView *view, NSString *targetText) {
    if (!view || view.hidden || view.alpha < 0.01) return nil;
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [[btn titleForState:UIControlStateNormal] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *accLabel = [btn.accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if ([title localizedCaseInsensitiveContainsString:targetText] || [accLabel localizedCaseInsensitiveContainsString:targetText]) {
            return btn;
        }
    }
    
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        if ([lbl.text localizedCaseInsensitiveContainsString:targetText]) {
            return view;
        }
    }
    
    NSString *generalAccLabel = [view.accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([generalAccLabel localizedCaseInsensitiveContainsString:targetText]) {
        return view;
    }
    
    for (UIView *subview in view.subviews) {
        UIView *found = findViewByTitleOrLabel(subview, targetText);
        if (found) return found;
    }
    
    return nil;
}

// دالة البحث الشاملة (تطبيق + ويب معاً)
static void smartClickElement(UIWindow *window, NSString *targetText) {
    if (!window) return;
    
    // 1. محاولة الضغط عبر عناصر التطبيق العادية
    UIView *targetView = findViewByTitleOrLabel(window, targetText);
    if (targetView) {
        UIWindow *win = targetView.window ?: window;
        [win makeKeyAndVisible];
        
        UIView *interactiveView = targetView;
        while (interactiveView && ![interactiveView isKindOfClass:[UIControl class]] && interactiveView.gestureRecognizers.count == 0) {
            interactiveView = interactiveView.superview;
        }
        if (!interactiveView) interactiveView = targetView;
        
        if ([interactiveView isKindOfClass:[UIControl class]]) {
            [(UIControl *)interactiveView sendActionsForControlEvents:UIControlEventTouchDown];
            [(UIControl *)interactiveView sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        
        for (UIGestureRecognizer *gr in interactiveView.gestureRecognizers) {
            if (gr.enabled) {
                [gr setValue:@(3) forKey:@"state"];
            }
        }
        
        [targetView sendActionsForControlEvents:UIControlEventAllEvents];
    }
    
    // 2. محاولة الضغط إذا كان العنصر داخل صفحة ويب (WKWebView)
    injectJavaScriptToHandleWebElements(window, targetText);
}

// دالة الرجوع للخلف الآمنة
static void goBackToPreviousScreen(UIWindow *window) {
    if (!window) return;
    UIViewController *rootVC = window.rootViewController;
    
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)rootVC popViewControllerAnimated:YES];
    } else {
        UIView *backBtn = findViewByTitleOrLabel(window, @"<");
        if (backBtn) {
            smartClickElement(window, @"<");
        } else {
            UIViewController *presentedVC = rootVC.presentedViewController;
            if (presentedVC && !presentedVC.isBeingDismissed) {
                [presentedVC dismissViewControllerAnimated:YES completion:nil];
            }
        }
    }
}

// الحلقة التلقائية الذكية والخارقة (تطبيق + ويب)
static void startMasterAutomationLoop(UIWindow *mainWindow) {
    if (!mainWindow) return;
    
    // الخطوة 1: ضغط Shake & Earn
    smartClickElement(mainWindow, @"Shake & Earn");
    
    // الخطوة 2: بعد ثانية، ضغط Start Shaking!
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        smartClickElement(mainWindow, @"Start Shaking!");
        
        // الخطوة 3: مراقبة ظهور Watch Ad & Earn بمهلة 5 ثوانٍ
        __block int elapsedSeconds = 0;
        __block BOOL adClicked = NO;
        
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
        
        dispatch_source_set_event_handler(timer, ^{
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) return;
            
            // التحقق من وجود الزر سواء كـ View عادية أو داخل ويب فيو
            UIView *watchAdView = findViewByTitleOrLabel(keyWindow, @"Watch Ad & Earn");
            
            if (watchAdView || elapsedSeconds >= 0) { // يتم الفحص الشامل
                // محاولة الضغط فوراً
                smartClickElement(keyWindow, @"Watch Ad & Earn");
                
                // نفترض نجاح الضغط وننتظر ثانيتين للرجوع
                adClicked = YES;
                dispatch_source_cancel(timer);
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    goBackToPreviousScreen(keyWindow);
                    
                    // إعادة تكرار العملية بسلاسة
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        startMasterAutomationLoop(keyWindow);
                    });
                });
            } else {
                elapsedSeconds++;
                if (elapsedSeconds >= 5 && !adClicked) {
                    dispatch_source_cancel(timer);
                    goBackToPreviousScreen(keyWindow);
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        startMasterAutomationLoop(keyWindow);
                    });
                }
            }
        });
        
        dispatch_resume(timer);
    });
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            startMasterAutomationLoop(window);
        });
    });
}

%end
