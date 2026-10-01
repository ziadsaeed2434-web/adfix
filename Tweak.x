#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"

static UITextView *universalLogView = nil;
static UIWindow *logWindow = nil;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logWindow) {
            // إنشاء نافذة مستقلة خاصة بالعرض العلوية تضمن ظهورها فوق أي واجهة للتطبيق
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                        logWindow = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
                        break;
                    }
                }
            }
            if (!logWindow) {
                logWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            }
            
            logWindow.windowLevel = UIWindowLevelAlert + 1000; // فوق جميع نوافذ التطبيق
            logWindow.backgroundColor = [UIColor clearColor];
            logWindow.hidden = NO;
            
            // إنشاء لوحة تحكم (ViewController) بسيطة للنافذة
            UIViewController *rootVC = [[UIViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            logWindow.rootViewController = rootVC;
            
            // تصميم اللوحة السوداء لعرض السجلات
            UIView *overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 40, rootVC.view.bounds.size.width - 20, 260)];
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

static void handleNetworkNotification(NSNotification *notification) {
    // طباعة اسم الإشعار والتأكد من عمل الرصد
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
    
    // إظهار رسالة تأكيد فور فتح التطبيق بأن الأداة تعمل
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showUniversalLog(@"[Init] Tweak injected successfully!");
    });
    
    // الاستماع لإشعارات شبكة FLEX
    [[NSNotificationCenter defaultCenter] addObserverForName:kFLEXNetworkRecorderNewTransactionNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
}
