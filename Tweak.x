#import <UIKit/UIKit.h>

// نافذة خضراء بسيطة تؤكد تفعيل الوضع المحلي للإعلانات
@interface CleanAdsHUD : NSObject
+ (void)showStatus;
@end

@implementation CleanAdsHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 220, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:0.85];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"⚡️ Local Ad Bypasser Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [CleanAdsHUD showStatus];
    });
}

// 1. تجاوز العدادات المحلية وقيود الأوقات (Cooldown) في التخزين
%hook NSUserDefaults
- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName containsString:@"count"] || [defaultName containsString:@"limit"] || [defaultName containsString:@"remaining"] || [defaultName containsString:@"left"]) {
        return 999;
    }
    return %orig;
}

- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName containsString:@"ready"] || [defaultName containsString:@"available"] || [defaultName containsString:@"loaded"] || [defaultName containsString:@"enabled"]) {
        return YES;
    }
    return %orig;
}

- (double)doubleForKey:(NSString *)defaultName {
    if ([defaultName containsString:@"time"] || [defaultName containsString:@"timestamp"] || [defaultName containsString:@"cooldown"]) {
        return 0.0; // تصفير وقت الانتظار ليصبح الإعلان متاحاً فورا
    }
    return %orig;
}
%end

// 2. ضمان سلامة التنبيهات الداخلية للتطبيق
%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)name object:(id)object userInfo:(NSDictionary *)userInfo {
    %orig;
}
%end
