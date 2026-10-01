#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"

static UITextView *universalLogView = nil;
static UIWindow *logWindow = nil;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logWindow) {
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                        logWindow = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
                        break;
                    }
                }
            }
            if (!logWindow) {
                logWindow = [[UIWindow alloc] initWithFrame:screenBounds];
            }
            
            logWindow.windowLevel = UIWindowLevelAlert + 1000;
            logWindow.backgroundColor = [UIColor clearColor];
            logWindow.hidden = NO;
            
            UIViewController *rootVC = [[UIViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            logWindow.rootViewController = rootVC;
            
            UIView *overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 45, screenBounds.size.width - 20, 260)];
            overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.95];
            overlay.layer.cornerRadius = 10;
            overlay.layer.borderWidth = 1.5;
            overlay.layer.borderColor = [UIColor orangeColor].CGColor;
            
            universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
            universalLogView.backgroundColor = [UIColor clearColor];
            universalLogView.textColor = [UIColor orangeColor];
            universalLogView.font = [UIFont fontWithName:@"Courier-Bold" size:10];
            universalLogView.editable = NO;
            universalLogView.text = @"[+] Network Monitor Active & Listening...\n";
            
            [overlay addSubview:universalLogView];
            [rootVC.view addSubview:overlay];
        }
        
        if (universalLogView) {
            NSString *oldText = universalLogView.text;
            universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
        }
    });
}

// دالة لإظهار رسالة تنبيه منبثقة تأكيدية على الشاشة فور الفتح
void showInjectionAlert() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
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
    NSString *log = [NSString stringWithFormat:@"[Event]: %@", notification.name];
    showUniversalLog(log);
}

%ctor {
    // تفعيل مسجل الشبكة
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    SEL selector = @selector(setEnabled:);
    if ([recorder respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [recorder performSelector:selector withObject:@(YES)];
        #pragma clang diagnostic pop
    }
    
    // إظهار رسالة المنبثقة والنافذة العلوية بعد إقلاع التطبيق بثانية واحدة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showInjectionAlert();
        showUniversalLog(@"[Init] Tweak injected & active!");
    });
    
    // الاستماع لطلبات الشبكة
    [[NSNotificationCenter defaultCenter] addObserverForName:kFLEXNetworkRecorderNewTransactionNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
}
