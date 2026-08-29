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
    
    // حقن مفاتيح الموافقة الخاصة بشبكات الإعلانات (مثل Google UMP / GDPR)
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    
    [def setBool:YES forKey:@"IABConsent_ParsedVendorConsents"];
    [def setObject:@"1" forKey:@"IABConsent_ConsentString"];
    [def setInteger:1 forKey:@"IABTCF_gdprApplies"];
    [def setObject:@"CPQ..." forKey:@"IABTCF_TCString"];
    
    // مفاتيح عامة لتجاوز الشروط ونافذة الموافقة
    [def setBool:YES forKey:@"gad_preferred_webview_utilization"];
    [def setBool:YES forKey:@"user_has_agreed_to_terms"];
    [def setBool:YES forKey:@"consent_given"];
    [def setBool:YES forKey:@"isConsentGiven"];
    [def synchronize];
}

// رصد مكتبة الـ UMP وإجبارها على اعتبار أن الموافقة تمت مسبقاً
%hook UMPConsentInformation
- (int)consentStatus {
    return 3; // 3 تعني Obtained (تم منح الموافقة)
}
- (BOOL)isConsentFormAvailable {
    return NO; // منع إظهار نموذج الشروط والخصوصية نهائياً
}
%end
