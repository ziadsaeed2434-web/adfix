#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>

// توليد معرف عشوائي جديد
NSString *generateNewUUID() {
    return [[NSUUID UUID] UUIDString];
}

// دالة تغيير وحفظ الـ IDFA
void changeIDFA() {
    NSString *newIDFA = generateNewUUID();
    [[NSUserDefaults standardUserDefaults] setObject:newIDFA forKey:@"CustomFakeIDFA_Btn"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// دالة تغيير وحفظ الـ UDID
void changeUDID() {
    NSString *newUDID = generateNewUUID();
    [[NSUserDefaults standardUserDefaults] setObject:newUDID forKey:@"CustomFakeUDID_Btn"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// هوك IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSString *fakeIDFA = [[NSUserDefaults standardUserDefaults] stringForKey:@"CustomFakeIDFA_Btn"];
    if (fakeIDFA) {
        return [[NSUUID alloc] initWithUUIDString:fakeIDFA];
    }
    return %orig;
}
%end

// هوك UDID
%hook UIDevice
- (NSUUID *)identifierForVendor {
    NSString *fakeUDID = [[NSUserDefaults standardUserDefaults] stringForKey:@"CustomFakeUDID_Btn"];
    if (fakeUDID) {
        return [[NSUUID alloc] initWithUUIDString:fakeUDID];
    }
    return %orig;
}
%end

// إنشاء زرين صغيرين ومنفصلين في أعلى الشاشة
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        UIViewController *rootVC = window.rootViewController;
        if (!rootVC) return;
        
        // زر تغيير UDID (في أعلى اليسار)
        UIButton *btnUDID = [UIButton buttonWithType:UIButtonTypeCustom];
        btnUDID.frame = CGRectMake(10, 45, 80, 25);
        [btnUDID setTitle:@"تغيير UDID" forState:UIControlStateNormal];
        [btnUDID setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnUDID.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        btnUDID.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
        btnUDID.layer.cornerRadius = 4;
        btnUDID.layer.zPosition = 99999;
        [btnUDID addTarget:nil action:@selector(actionChangeUDID) forControlEvents:UIControlEventTouchUpInside];
        
        // زر تغيير IDFA (بجانبه في الأعلى)
        UIButton *btnIDFA = [UIButton buttonWithType:UIButtonTypeCustom];
        btnIDFA.frame = CGRectMake(95, 45, 80, 25);
        [btnIDFA setTitle:@"تغيير IDFA" forState:UIControlStateNormal];
        [btnIDFA setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnIDFA.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        btnIDFA.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.8];
        btnIDFA.layer.cornerRadius = 4;
        btnIDFA.layer.zPosition = 99999;
        [btnIDFA addTarget:nil action:@selector(actionChangeIDFA) forControlEvents:UIControlEventTouchUpInside];
        
        [rootVC.view addSubview:btnUDID];
        [rootVC.view addSubview:btnIDFA];
        [rootVC.view bringSubviewToFront:btnUDID];
        [rootVC.view bringSubviewToFront:btnIDFA];
    });
}

// أهداف الأزرار
@interface NSObject (ButtonActions)
@end
@implementation NSObject (ButtonActions)
- (void)actionChangeUDID {
    changeUDID();
}
- (void)actionChangeIDFA {
    changeIDFA();
}
@end

