#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"

// تعريف دالة النافذة العلوية
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

// دالة لاستقبال تحديثات طلبات الشبكة من FLEX
static void handleNetworkNotification(NSNotification *notification) {
    // استخراج معرف الطلب أو كائن الطلب المسجل
    NSString *requestID = notification.userInfo[FLEXNetworkRecorderRequestIDKey];
    if (!requestID) return;
    
    // جلب تفاصيل الطلب من المسجل
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder sharedRecorder];
    
    // يمكنك الحصول على الرابط ومعلومات الاستجابة
    NSString *url = [recorder URLStringForRequestID:requestID];
    NSData *responseBody = [recorder responseDataForRequestID:requestID];
    NSString *method = [recorder requestMethodForRequestID:requestID];
    
    if (url) {
        NSString *responseString = @"";
        if (responseBody) {
            responseString = [[NSString alloc] initWithData:responseBody encoding:NSUTF8StringEncoding];
            if (!responseString) {
                responseString = [NSString stringWithFormat:@"[Binary Data: %lu bytes]", (unsigned long)responseBody.length];
            }
            // تقييد الطول حتى لا تمتلئ الذاكرة بسرعة إذا كان الاستجابة ضخمة
            if (responseString.length > 1000) {
                responseString = [responseString substringToIndex:1000];
                responseString = [responseString stringByAppendingString:@"... (truncated)"];
            }
        }
        
        NSString *log = [NSString *][format: @"[%@] %@\nResponse:\n%@", method, url, responseString];
        showUniversalLog(log);
    }
}

%ctor {
    // 1. تفعيل مراقبة الشبكة تلقائياً
    [[FLEXNetworkRecorder sharedRecorder] setEnabled:YES];
    
    // 2. الاستماع لإشعارات تسجيل طلبات الشبكة الجديدة من FLEX
    [[NSNotificationCenter defaultCenter] addObserverForName:FLEXNetworkRecorderNewRequestNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:FLEXNetworkRecorderResponseReceivedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        handleNetworkNotification(note);
    }];
}
