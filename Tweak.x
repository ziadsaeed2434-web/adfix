#import <UIKit/UIKit.h>

@interface ForceAgreeHUD : NSObject
+ (void)showStatus;
@end

@implementation ForceAgreeHUD
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
        lbl.text = @"⚡️ Force Agree & Bypasser Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

// دالة مساعدة للبحث داخل الأزرار والعناصر عن كلمة "AGREE" أو "موافق" وضغطها تلقائياً
static void findAndClickAgreeButton(UIView *view) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *btnText = btn.titleLabel.text;
            if (btnText && ([btnText localizedCaseInsensitiveContainsString:@"AGREE"] || 
                            [btnText localizedCaseInsensitiveContainsString:@"Accept"] || 
                            [btnText localizedCaseInsensitiveContainsString:@"موافق"])) {
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
        // البحث بشكل متعمق داخل الـ Subviews
        if (subview.subviews.count > 0) {
            findAndClickAgreeButton(subview);
        }
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ForceAgreeHUD showStatus];
    });
    
    // حقن قيم الموافقة كإجراء احتياطي
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:YES forKey:@"IABConsent_ParsedVendorConsents"];
    [def setObject:@"1" forKey:@"IABConsent_ConsentString"];
    [def setBool:YES forKey:@"user_has_agreed_to_terms"];
    [def setBool:YES forKey:@"consent_given"];
    [def synchronize];
}

// مراقبة ظهور أي نافذة جديدة (ViewController) وفحصها فور ظهورها لضغط زر الموافقة أو إخفائها
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // فحص الشاشة الحالية بحثاً عن زر AGREE لضغطه آلياً
        findAndClickAgreeButton(self.view);
        
        // فحص إذا كانت هذه الشاشة هي نافذة الخصوصية/الموافقة عبر تفقد نصوصها وإبعادها إذا لزم الأمر
        NSString *className = NSStringFromClass([self class]);
        if ([className localizedCaseInsensitiveContainsString:@"Consent"] || 
            [className localizedCaseInsensitiveContainsString:@"Privacy"] || 
            [className localizedCaseInsensitiveContainsString:@"GDPR"] ||
            [className localizedCaseInsensitiveContainsString:@"UMP"]) {
            // إخفاء نافذة الموافقة بالكامل فور ظهورها
            [self.view setHidden:YES];
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    });
}
%end
