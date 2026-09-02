#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// دالة البحث والضغط على الأزرار التقليدية (UIButton)
static void clickNativeAgreeButton(UIView *view) {
    if (!view) return;
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            // التصحيح هنا: استخدام NSNotFound بدلاً من المعرف الخاطئ
            if (title && [title rangeOfString:@"AGREE" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if ([title.uppercaseString containsString:@"AGREE"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                    });
                    return;
                }
            }
        }
        
        // التحقق إذا كان العنصر WebView لمحاولة تنفيذ حقن جافاسكريبت للضغط
        if ([subview isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)subview;
            NSString *jsCode = @"(function() {"
                               "  var buttons = document.querySelectorAll('button, div, span, a');"
                               "  for (var i = 0; i < buttons.length; i++) {"
                               "    var text = buttons[i].innerText || buttons[i].textContent;"
                               "    if (text && text.trim().toUpperCase() === 'AGREE') {"
                               "      buttons[i].click();"
                               "      return 'Clicked';"
                               "    }"
                               "  }"
                               "})();";
            [webView evaluateJavaScript:jsCode completionHandler:nil];
        }
        
        if (subview.subviews.count > 0) {
            clickNativeAgreeButton(subview);
        }
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // الانتظار حتى تظهر النافذة تماماً وتستقر العناصر
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.isViewLoaded && self.view) {
            @try {
                clickNativeAgreeButton(self.view);
            } @catch (NSException *exception) {
                NSLog(@"AutoAgree Tweak Exception: %@", exception.reason);
            }
        }
    });
}

%end
