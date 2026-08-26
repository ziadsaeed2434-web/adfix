#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 0.0;
static double sessionLongitude = 0.0;
static NSString *sessionAtlantaIP = nil;
static NSMutableArray *networkLogs = nil;
static UIButton *globalDebugButton = nil; // متغير عام لضمان بقاء زر واحد دائم

static void initializeNewSessionData() {
    double randomLatOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double randomLonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    
    sessionLatitude = 33.7490 + randomLatOffset;
    sessionLongitude = -84.3880 + randomLonOffset;
    
    NSArray *atlantaIPRanges = @[
        [NSString stringWithFormat:@"104.28.%d.%d", arc4random_uniform(200) + 10, arc4random_uniform(254) + 1],
        [NSString stringWithFormat:@"172.56.%d.%d", arc4random_uniform(50) + 10, arc4random_uniform(254) + 1], 
        [NSString stringWithFormat:@"73.152.%d.%d", arc4random_uniform(100) + 10, arc4random_uniform(254) + 1],  
        [NSString stringWithFormat:@"68.174.%d.%d", arc4random_uniform(100) + 10, arc4random_uniform(254) + 1]   
    ];
    
    int randomIndex = arc4random_uniform((int)[atlantaIPRanges count]);
    sessionAtlantaIP = atlantaIPRanges[randomIndex];
    
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    } else {
        [networkLogs removeAllObjects];
    }
}

%ctor {
    initializeNewSessionData();
}

// دالة عرض النافذة والسجل
@interface NetworkLogViewer : NSObject
@end

@implementation NetworkLogViewer
+ (void)showLogsMenu {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
    
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    NSMutableString *message = [NSMutableString stringWithFormat:@"🌐 Atlanta IP: %@\n\n--- الطلبات الصادرة (%lu) ---\n", sessionAtlantaIP, (unsigned long)[networkLogs count]];
    
    NSInteger startIdx = [networkLogs count] > 15 ? [networkLogs count] - 15 : 0;
    for (NSInteger i = [networkLogs count] - 1; i >= startIdx; i--) {
        [message appendFormat:@"• %@\n", networkLogs[i]];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"سجل الآبي والشبكة" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح السجل" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [networkLogs removeAllObjects];
    }]];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}
@end

// تثبيت الزر العائم وجعله يظهر فوق أي صفحة تنتقل إليها
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if (!globalDebugButton) {
        globalDebugButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [globalDebugButton setTitle:@"IP Logs" forState:UIControlStateNormal];
        [globalDebugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        globalDebugButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        globalDebugButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.9];
        globalDebugButton.layer.cornerRadius = 20;
        globalDebugButton.frame = CGRectMake(20, 100, 75, 40);
        
        // إعطاء الزر أعلى ترتيب (Z-Position) لكي لا يختفي خلف أي صفحة
        globalDebugButton.layer.zPosition = 999999;
        
        [globalDebugButton addTarget:[NetworkLogViewer class] action:@selector(showLogsMenu) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // التأكد من وضع الزر في الشاشة الرئيسية وعدم اختفائه عند تغير الواجهات
    if (self.rootViewController && self.rootViewController.view) {
        [globalDebugButton removeFromSuperview]; // إزالته من أي مكان قديم وتثبيته في النافذة النشطة
        [self.rootViewController.view addSubview:globalDebugButton];
        [self.rootViewController.view bringSubviewToFront:globalDebugButton];
    }
}

%end

// 1. تثبيت موقع أتلانتا
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 2. مراقبة وتسجيل الطلبات والآبي
%hook NSMutableURLRequest

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame) {
        %orig(sessionAtlantaIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString) {
        NSString *logEntry = [NSString stringWithFormat:@"[%@] %@", sessionAtlantaIP, url.absoluteString];
        if (networkLogs && ![networkLogs containsObject:logEntry]) {
            if ([networkLogs count] > 100) [networkLogs removeObjectAtIndex:0];
            [networkLogs addObject:logEntry];
        }
    }
}

%end
