#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <SystemConfiguration/SystemConfiguration.h>

static NSString *currentSessionIDFA = nil;
static BOOL autoCleanEnabled = YES;

@interface ProAdManagerController : NSObject
+ (instancetype)sharedInstance;
- (void)showFloatingButton;
- (NSString *)getOrCreateUUID;
- (void)wipeAppData;
@end

@implementation ProAdManagerController {
    UIButton *floatingBtn;
    UIView *menuPanel;
    UILabel *statusLabel;
    UISwitch *cleanSwitch;
}

+ (instancetype)sharedInstance {
    static ProAdManagerController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)wipeAppData {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSArray *paths = @[@"Documents", @"Library/Caches", @"Library/Preferences", @"tmp"];
    
    for (NSString *p in paths) {
        NSString *fullPath = [home stringByAppendingPathComponent:p];
        for (NSString *file in [fm contentsOfDirectoryAtPath:fullPath error:nil]) {
            [fm removeItemAtPath:[fullPath stringByAppendingPathComponent:file] error:nil];
        }
    }
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)getOrCreateUUID {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        if (autoCleanEnabled) {
            [self wipeAppData];
        }
        currentSessionIDFA = [[NSUUID UUID] UUIDString];
    });
    return currentSessionIDFA;
}

- (void)showFloatingButton {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    if (floatingBtn) return;

    floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake(15, 120, 55, 55);
    floatingBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.85];
    [floatingBtn setTitle:@"🛡️" forState:UIControlStateNormal];
    floatingBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    floatingBtn.layer.cornerRadius = 27.5;
    floatingBtn.layer.borderWidth = 1.5;
    floatingBtn.layer.borderColor = [UIColor systemGreenColor].CGColor;
    
    floatingBtn.layer.shadowColor = [UIColor systemGreenColor].CGColor;
    floatingBtn.layer.shadowRadius = 8;
    floatingBtn.layer.shadowOpacity = 0.6;
    
    [floatingBtn addTarget:self action:@selector(toggleMenuPanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragButton:)];
    [floatingBtn addGestureRecognizer:pan];

    [window addSubview:floatingBtn];
}

- (void)dragButton:(UIPanGestureRecognizer * )pan {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CGPoint translation = [pan translationInView:window];
    CGPoint center = floatingBtn.center;
    floatingBtn.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [pan setTranslation:CGPointZero inView:window];
}

- (void)toggleMenuPanel {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (menuPanel) {
        [UIView animateWithDuration:0.25 animations:^{
            menuPanel.alpha = 0;
            menuPanel.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            [menuPanel removeFromSuperview];
            menuPanel = nil;
        }];
        return;
    }

    menuPanel = [[UIView alloc] initWithFrame:CGRectMake(30, 160, window.bounds.size.width - 60, 390)];
    menuPanel.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.92];
    menuPanel.layer.cornerRadius = 24;
    menuPanel.layer.borderWidth = 1;
    menuPanel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    menuPanel.transform = CGAffineTransformMakeScale(0.8, 0.8);
    menuPanel.alpha = 0;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, menuPanel.bounds.size.width - 40, 30)];
    title.text = @"🛠️ أداة الحماية ومنع كشف الـ VPN";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    title.textAlignment = NSTextAlignmentCenter;
    [menuPanel addSubview:title];

    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, menuPanel.bounds.size.width - 40, 110)];
    statusLabel.textColor = [UIColor systemGreenColor];
    statusLabel.font = [UIFont fontWithName:@"Courier-Bold" size:11];
    statusLabel.numberOfLines = 0;
    [self updateStatusText];
    [menuPanel addSubview:statusLabel];

    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 185, 200, 30)];
    switchLabel.text = @"مسح الداتا عند الفتح:";
    switchLabel.textColor = [UIColor lightGrayColor];
    switchLabel.font = [UIFont systemFontOfSize:13];
    [menuPanel addSubview:switchLabel];

    cleanSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(menuPanel.bounds.size.width - 80, 185, 0, 0)];
    cleanSwitch.on = autoCleanEnabled;
    [cleanSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [menuPanel addSubview:cleanSwitch];

    UIButton *regenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    regenBtn.frame = CGRectMake(20, 235, menuPanel.bounds.size.width - 40, 44);
    regenBtn.backgroundColor = [UIColor systemIndigoColor];
    [regenBtn setTitle:@"🔄 توليد هوية جديدة الآن" forState:UIControlStateNormal];
    [regenBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    regenBtn.layer.cornerRadius = 14;
    regenBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [regenBtn addTarget:self action:@selector(manualRegenerate) forControlEvents:UIControlEventTouchUpInside];
    [menuPanel addSubview:regenBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 295, menuPanel.bounds.size.width - 40, 44);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    [closeBtn setTitle:@"إخفاء القائمة" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 14;
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [closeBtn addTarget:self action:@selector(toggleMenuPanel) forControlEvents:UIControlEventTouchUpInside];
    [menuPanel addSubview:closeBtn];

    [window addSubview:menuPanel];

    [UIView animateWithDuration:0.25 animations:^{
        menuPanel.alpha = 1.0;
        menuPanel.transform = CGAffineTransformIdentity;
    }];
}

- (void)updateStatusText {
    statusLabel.text = [NSString stringWithFormat:
                        @"📌 حماية الـ VPN: نشطة ومخفية\n"
                        @"🆔 IDFA الحالي:\n%@\n"
                        @"🛡️ تتبع الإعلانات: مسموح (YES)",
                        [self getOrCreateUUID]];
}

- (void)switchChanged:(UISwitch *)sender {
    autoCleanEnabled = sender.isOn;
}

- (void)manualRegenerate {
    currentSessionIDFA = [[NSUUID UUID] UUIDString];
    if (autoCleanEnabled) {
        [self wipeAppData];
    }
    [self updateStatusText];
    
    statusLabel.textColor = [UIColor systemCyanColor];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        statusLabel.textColor = [UIColor systemGreenColor];
    });
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ProAdManagerController sharedInstance] showFloatingButton];
    });
}

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManagerController sharedInstance] getOrCreateUUID]];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManagerController sharedInstance] getOrCreateUUID]];
}
%end

%hook NSDictionary
- (id)objectForKey:(id)aKey {
    if ([aKey isKindOfClass:[NSString class]]) {
        if ([(NSString *)aKey isEqualToString:@"HTTPEnable"] || [(NSString *)aKey isEqualToString:@"HTTPProxy"]) {
            return nil;
        }
    }
    return %orig;
}
%end

%hook NSURLSessionConfiguration
- (NSDictionary *)connectionProxyDictionary {
    return nil;
}
%end
