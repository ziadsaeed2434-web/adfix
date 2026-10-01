#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"

static UITextView *universalLogView = nil;

void showUniversalLog(NSString *logText) {
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
        
        if (keyWindow) {
            UIView *overlay = [keyWindow viewWithTag:999888];
            if (!overlay) {
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 35, keyWindow.bounds.size.width - 20, 280)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.92];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:9];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] FLEX Network Monitor Active...\n";
                
                [overlay addSubview:universalLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

static void handleNetworkNotification(NSNotification *notification) {
    // استخدام الأسماء الصحيحة حسب إصدار FLEX لديك
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    
    // جلب المعاملات أو الرابط بالطريقة المتاحة
    // ملاحظة: يمكنك طباعة الإشعار أو تفاصيل المعاملات المتوفرة
    NSString *log = [NSString stringWithFormat:@"[Network Notification Received] %@", notification.name];
    showUniversalLog(log);
}

%ctor {
    // تفعيل المسجل بالطريقة الصحيحة (defaultRecorder)
    [[FLEXNetworkRecorder defaultRecorder] setEnabled:YES];
    
    // استخدام الإشعار الصحيح المعرف في هيدر مكتبتك (kFLEXNetworkRecorderNewTransactionNotification)
    [[NSNotificationCenter defaultCenter] addObserverForName:kFLEXNetworkRecorderNewTransactionNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
}
