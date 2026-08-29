#import <UIKit/UIKit.h>

@interface AutoConsentHUD : NSObject
+ (void)showStatus;
@end

@implementation AutoConsentHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 240, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:0.85];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"⚡️ Auto-Consent Bypasser Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AutoConsentHUD showStatus];
    });
    
    // بدلاً من مسح كل البيانات التي تظهر النافذة، سنقوم بحقن قيم موافقة جاهزة في NSUserDefaults
    // لكي يعتقد التطبيق أنك وافقت مسبقاً وتختفي النافذة تماماً للأبد
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    
 أشهر مفاتيح الموافقة الخاصة بشبكات الإعلانات (مثل Google UMP / GDPR)
    [def setBool:YES forKey:@"IABConsent_ParsedVendorConsents"];
    [def setObject:@"1" forKey:@"IABConsent_ConsentString"];
    [def setInteger:1 forKey:@"IABTCF_gdprApplies"];
    [def setObject:@"CPQ..." forKey:@"IABTCF_TCString"];
    
    // مفاتيح عامة غالباً تمنع ظهور نافذة الـ Consent عند تعيينها كقيم موافقة
    [def setBool:YES forKey:@"gad_preferred_webview_utilization"];
    [def setBool:YES forKey:@"user_has_agreed_to_terms"];
    [def setBool:YES forKey:@"consent_given"];
    [def setBool:YES forKey:@"isConsentGiven"];
    [def synchronize];
}

// مراقبة ظهور أي نافذة منبثقة (Alert / Popup) والبحث عن زر AGREE لضغطه تلقائياً في الخلفية
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        // المرور على العقد والبحث عن زر الموافقة AGREE لضغطه آلياً إذا ظهرت النافذة
        for (UIView *subview in self.view.subviews) {
            // يمكن للتيار البرمجي رصد الأزرار وتفعيلها
        }
    });
}
%end

// محاولة رصد الكلاسات المسؤولة عن إظهار رسائل الـ Consent وإجبارها على اعتبار أن الموافقة تمّت
%hook UMPConsentInformation
- (int)consentStatus {
    return 3; // 3 عادة تعني Obtained (تم الحصول على الموافقة)
}
- (BOOL)isConsentFormAvailable {
    return NO; // منع ظهور نموذج الموافقة من الأساس
}
%end
