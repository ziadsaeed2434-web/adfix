#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static void clickButtonWithText(UIView *view, NSString *targetText) {
    if (!view) return;
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            if (title && [title.uppercaseString containsString:targetText.uppercaseString]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                });
                return;
            }
        }
        
        if ([subview isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)subview;
            NSString *jsCode = [NSString stringWithFormat:
                                @"(function() {"
                                "  var elements = document.querySelectorAll('button, div, span, a, input');"
                                "  for (var i = 0; i < elements.length; i++) {"
                                "    var text = elements[i].innerText || elements[i].textContent || elements[i].value;"
                                "    if (text && text.trim().toUpperCase().indexOf('%@') !== -1) {"
                                "      elements[i].click();"
                                "      return 'Clicked';"
                                "    }"
                                "  }"
                                "})();", targetText.uppercaseString];
            [webView evaluateJavaScript:jsCode completionHandler:nil];
        }
        
        if (subview.subviews.count > 0) {
            clickButtonWithText(subview, targetText);
        }
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // متغير ثابت لضمان تشغيل الأتمتة مرة واحدة فقط عند فتح التطبيق
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 1. الضغط على AGREE بعد ثانيتين من فتح التطبيق
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.isViewLoaded && self.view) {
                @try {
                    clickButtonWithText(self.view, @"AGREE");
                } @catch (NSException *exception) {
                    NSLog(@"AutoAgree Error: %@", exception.reason);
                }
            }
        });
        
        // 2. بعد 7 ثوانٍ إضافية، الانتقال لصفحة Store (بالبحث عن زر Store والضغط عليه)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.0 + 7.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.isViewLoaded && self.view) {
                @try {
                    clickButtonWithText(self.view, @"Store");
                } @catch (NSException *exception) {
                    NSLog(@"GoToStore Error: %@", exception.reason);
                }
            }
        });
        
        // 3. بعد 7 ثوانٍ أخرى (حتى يتحمل المتجر)، الضغط على زر (watch ad)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.0 + 7.0 + 7.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.isViewLoaded && self.view) {
                @try {
                    clickButtonWithText(self.view, @"watch ad");
                } @catch (NSException *exception) {
                    NSLog(@"WatchAd Error: %@", exception.reason);
                }
            }
        });
        
        // 4. بعد 65 ثانية من عرض الإعلان، إغلاق التطبيق تماماً
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.0 + 7.0 + 7.0 + 65.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                exit(0);
            } @catch (NSException *exception) {
                NSLog(@"Exit App Error: %@", exception.reason);
            }
        });
        
    });
}

%end
