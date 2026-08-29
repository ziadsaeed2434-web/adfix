#import <UIKit/UIKit.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

@interface AutoAllowHUD : NSObject
+ (void)showStatus;
@end

@implementation AutoAllowHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 240, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0 green:0.6 blue:0 alpha:0.85];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"✅ Auto Allow Tracking Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AutoAllowHUD showStatus];
    });
    
    // مسح الذاكرة المحلية للتطبيق ليبقى في وضع التثبيت الجديد
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [def dictionaryRepresentation];
    for (NSString *key in [dict allKeys]) {
        if (![key hasPrefix:@"NS"] && ![key hasPrefix:@"Apple"]) {
            [def removeObjectForKey:key];
        }
    }
    [def synchronize];
}

// إجبار حالة إذن التتبع على العودة كـ "مسموح به" (Authorized) تلقائياً
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 3; // 3 يمثل ATTrackingManagerAuthorizationStatusAuthorized (مسموح)
}

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(NSUInteger status))completion {
    if (completion) {
        completion(3); // إرجاع الموافقة فوراً للبرنامج
    }
}
%end
