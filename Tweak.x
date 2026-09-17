#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// دالة البحث وإخفاء النافذة إذا احتوت على كلمات الموافقة
static void hideConsentWindowRecursively(UIView *view) {
    if (!view) return;
    NSArray *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        
        // التحقق من الأزرار أو النصوص العادية للتأكد من أنها نافذة الموافقة
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if (text && ([text rangeOfString:@"personal data" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                         [text rangeOfString:@"consent" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                         [text rangeOfString:@"advertising and content" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
                
                // إخفاء الـ View الحامل للنافذة بالكامل
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIView *targetView = subview;
                    // صعد للأعلى للوصول للحاوية الرئيسية للنافذة وإخفائها بالكامل
                    for (int i = 0; i < 4; i++) {
                        if (targetView.superview && targetView.superview != targetView.window) {
                            targetView = targetView.superview;
                        }
                    }
                    targetView.hidden = YES;
                    targetView.alpha = 0.0;
                    [targetView setUserInteractionEnabled:NO];
                });
                return;
            }
        }
        
        // التحقق إذا كانت النافذة معروضة داخل WKWebView وإخفاؤها
        if ([subview isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)subview;
            NSString *jsCode = @"(function() {"
                               "  var bodyText = document.body ? document.body.innerText : '';"
                               "  if (bodyText.indexOf('consent') !== -1 || bodyText.indexOf('personal data') !== -1) {"
                               "     var container = document.querySelector('div');"
                               "     if(container) { container.style.display = 'none'; }"
                               "     return 'Hidden';"
                               "  }"
                               "})();";
            [webView evaluateJavaScript:jsCode completionHandler:nil];
        }
        
        if (subview.subviews.count > 0) {
            hideConsentWindowRecursively(subview);
        }
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // استخدام نفس مؤقت الانتظار الناجح في كودك (0.6 ثانية) لتستقر النافذة ثم يتم إخفاؤها فوراً
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.isViewLoaded && self.view) {
            @try {
                hideConsentWindowRecursively(self.view);
            } @catch (NSException *exception) {
                NSLog(@"HideConsent Tweak Exception: %@", exception.reason);
            }
        }
    });
}

%end
