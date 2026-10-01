#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"

static UITextView *universalLogView = nil;
static UIView *globalOverlayView = nil;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow) {
            if (!globalOverlayView) {
                CGRect screenBounds = keyWindow.bounds;
                globalOverlayView = [[UIView alloc] initWithFrame:CGRectMake(10, 45, screenBounds.size.width - 20, 260)];
                globalOverlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.95];
                globalOverlayView.layer.cornerRadius = 10;
                globalOverlayView.layer.borderWidth = 1.5;
                globalOverlayView.layer.borderColor = [UIColor orangeColor].CGColor;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, globalOverlayView.bounds.size.width - 10, globalOverlayView.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier-Bold" size:9];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] Network Monitor Active & Listening...\n";
                
                [globalOverlayView addSubview:universalLogView];
                [keyWindow addSubview:globalOverlayView];
            }
            
            // التأكد من إحضار النافذة دائماً في المقدمة فوق جميع عناصر التطبيق
            [keyWindow bringSubviewToFront:globalOverlayView];
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

void showInjectionAlert() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        UIViewController *topController = keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        
        if (topController) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"نجح الحقن"
                                                                            message:@"التويك شغال ومراقبة الشبكة مفعلة بنجاح!"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
            [topController presentViewController:alert animated:YES completion:nil];
        }
    });
}

static void handleNetworkNotification(NSNotification *notification) {
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    NSArray *transactions = [recorder networkTransactions];
    
    if (transactions.count > 0) {
        id transaction = [transactions lastObject];
        
        NSString *method = [transaction valueForKey:@"method"];
        NSURL *url = [transaction valueForKey:@"requestURL"];
        if (!url) {
            url = [[transaction valueForKey:@"request"] URL];
        }
        
        NSData *responseData = [transaction valueForKey:@"responseData"];
        NSString *responseString = @"";
        
        if (responseData) {
            responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            if (!responseString) {
                responseString = [NSString stringWithFormat:@"[Binary Data: %lu bytes]", (unsigned long)responseData.length];
            }
            if (responseString.length > 500) {
                responseString = [[responseString substringToIndex:500] stringByAppendingString:@"...\n(truncated)"];
            }
        } else {
            responseString = @"[No Response Body / Loading...]";
        }
        
        NSString *log = [NSString stringWithFormat:@"[%@] %@\nRes: %@", method ?: @"REQ", url.absoluteString ?: @"Unknown URL", responseString];
        showUniversalLog(log);
    }
}

%ctor {
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    SEL selector = @selector(setEnabled:);
    if ([recorder respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [recorder performSelector:selector withObject:@(YES)];
        #pragma clang diagnostic pop
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showInjectionAlert();
        showUniversalLog(@"[Init] Tweak injected & Network Recorder Active!");
    });
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kFLEXNetworkRecorderNewTransactionNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
}
