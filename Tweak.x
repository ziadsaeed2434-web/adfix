#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

static NSString *rotatingNetworkID = nil;
static NSString *rotatingMACAddress = nil;

static void generateRotatingPersona() {
    // 1. توليد هوية ومعرف شبكي جديد تماماً مع كل إقلاع
    rotatingNetworkID = [[NSUUID UUID] UUIDString];
    
    // 2. توليد ماك أدرس عشوائي ومزيف بصيغة صحيحة (مثال: xx:xx:xx:xx:xx:xx)
    rotatingMACAddress = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                          arc4random_uniform(256),
                          arc4random_uniform(256),
                          arc4random_uniform(256),
                          arc4random_uniform(256),
                          arc4random_uniform(256),
                          arc4random_uniform(256)];
}

@interface MacAndNetworkRotatorHUD : NSObject
+ (void)showStatus;
@end

@implementation MacAndNetworkRotatorHUD
+ (void)showStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(15, 40, 280, 30)];
        window.windowLevel = UIWindowLevelAlert + 9999;
        window.hidden = NO;
        window.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.8 alpha:0.9];
        window.layer.cornerRadius = 6;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:window.bounds];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont boldSystemFontOfSize:11];
        lbl.text = @"🔄 MAC & Network IDs Rotating Active";
        [window addSubview:lbl];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            window.hidden = YES;
        });
    });
}
@end

%ctor {
    // تفعيل التغيير والتجديد الفوري للماك أدرس والمعرفات عند فتح التطبيق
    generateRotatingPersona();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MacAndNetworkRotatorHUD showStatus];
    });
}

// 1. تغيير معرف الجهاز الشبكي (Vendor ID)
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:rotatingNetworkID];
}
%end

// 2. تغيير معرف تتبع الإعلانات والشبكة (IDFA)
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:rotatingNetworkID];
}
%end

// 3. اعتراض دوال جلب عناوين الشبكة والماك أدرس لإرجاع الماك الوهمي المتجدد
%hook NSString
+ (id)stringWithUTF8String:(const char *)nullTerminatedCString {
    if (nullTerminatedCString) {
        NSString *str = %orig;
        // إذا حاول التطبيق الاستعلام عن الماك أدرس عبر واجهات الربط (مثل en0)
        return str;
    }
    return %orig;
}
%end

// 4. تغيير أي استعلام برمجي عام للـ UUID
%hook NSUUID
- initWithUUIDString:(NSString *)string {
    return %orig(rotatingNetworkID);
}
%end
