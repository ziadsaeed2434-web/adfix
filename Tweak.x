#import <UIKit/UIKit.h>
#import "FLEXNetworkRecorder.h"
#import "FLEXNetworkObserver.h"

static UITextView *universalLogView = nil;
static UIView *globalOverlayView = nil;
static NSUInteger lastProcessedCount = 0;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
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
                universalLogView.text = @"[+] All Requests Monitor Active...\n";
                
                [globalOverlayView addSubview:universalLogView];
                [keyWindow addSubview:globalOverlayView];
            }
            
            [keyWindow bringSubviewToFront:globalOverlayView];
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

void processAllNewTransactions() {
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    NSArray *transactions = [recorder networkTransactions];
    
    if (transactions.count > lastProcessedCount) {
        // معالجة كل الطلبات الجديدة التي لم يتم عرضها بعد
        for (NSUInteger i = lastProcessedCount; i < transactions.count; i++) {
            id transaction = transactions[i];
            
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
                if (responseString.length > 350) {
                    responseString = [[responseString substringToIndex:350] stringByAppendingString:@"...\n(truncated)"];
                }
            } else {
                responseString = @"[Pending / Loading...]";
            }
            
            NSString *log = [NSString stringWithFormat:@"[%@] %@\nRes: %@", method ?: @"REQ", url.absoluteString ?: @"Unknown URL", responseString];
            showUniversalLog(log);
        }
        lastProcessedCount = transactions.count;
    }
}

%ctor {
    [FLEXNetworkRecorder defaultRecorder];
    
    SEL enableObs = @selector(enable);
    if ([FLEXNetworkObserver respondsToSelector:enableObs]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [FLEXNetworkObserver performSelector:enableObs];
        #pragma clang diagnostic pop
    }
    
    SEL setRec = @selector(setEnabled:);
    FLEXNetworkRecorder *recorder = [FLEXNetworkRecorder defaultRecorder];
    if ([recorder respondsToSelector:setRec]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [recorder performSelector:setRec withObject:@(YES)];
        #pragma clang diagnostic pop
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showUniversalLog(@"[Init] Ready to capture ALL network traffic!");
    });
    
    // الاستماع الفوري لإشعارات المعاملات الجديدة
    [[NSNotificationCenter defaultCenter] addObserverForName:kFLEXNetworkRecorderNewTransactionNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        processAllNewTransactions();
    }];
    
    // فحص فائض سريع كل نصف ثانية لضمان عدم ضياع أي طلب مهما كانت الظروف
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 0.5 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        processAllNewTransactions();
    });
    dispatch_resume(timer);
}
