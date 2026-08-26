#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 0.0;
static double sessionLongitude = 0.0;
static NSString *sessionAtlantaIP = nil;
static NSMutableArray *networkLogs = nil;
static UIButton *globalDebugButton = nil;

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

// واجهة عرض سجل الطلبات
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
    
    NSMutableString *message = [NSMutableString stringWithFormat:@"🌐 Active Atlanta IP: %@\n\n--- الطلبات المسجلة (%lu) ---\n", sessionAtlantaIP, (unsigned long)[networkLogs count]];
    
    NSInteger startIdx = [networkLogs count] > 15 ? [networkLogs count] - 15 : 0;
    for (NSInteger i = [networkLogs count] - 1; i >= startIdx; i--) {
        [message appendFormat:@"• %@\n", networkLogs[i]];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"مراقب الآبي والشبكة" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح السجل" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [networkLogs removeAllObjects];
    }]];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}
@end

// دالة تحريك الزر العائم في أي مكان بإصبعك
@interface DraggableButtonHandler : NSObject
@end

@implementation DraggableButtonHandler
+ (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIButton *button = (UIButton *)gesture.view;
    CGPoint translation = [gesture translationInView:button.superview];
    
    CGPoint newCenter = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    button.center = newCenter;
    
    [gesture setTranslation:CGPointZero inView:button.superview];
}
@end

// تثبيت الزر العائم وجعله قابلاً للسحب وفوق كل الصفحات
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
        globalDebugButton.layer.zPosition = 999999;
        
        [globalDebugButton addTarget:[NetworkLogViewer class] action:@selector(showLogsMenu) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[DraggableButtonHandler class] action:@selector(handlePan:)];
        [globalDebugButton addGestureRecognizer:pan];
    }
    
    if (self.rootViewController && self.rootViewController.view) {
        [globalDebugButton removeFromSuperview];
        [self.rootViewController.view addSubview:globalDebugButton];
        [self.rootViewController.view bringSubviewToFront:globalDebugButton];
    }
}

%end

// 1. تثبيت موقع أتلانتا الجغرافي
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 2. إجبار التطبيق على أخذ الآبي الجديد في كل جلسات الاتصال الحديثة (NSURLSession)
%hook NSURLSessionConfiguration

- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy];
    if (!modifiedHeaders) {
        modifiedHeaders = [NSMutableDictionary dictionary];
    }
    
    // حقن الآبي الجديد كمعيار رئيسي في ترويسات جلسة الشبكة
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"X-Forwarded-For"];
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"Client-IP"];
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"X-Real-IP"];
    
    %orig(modifiedHeaders);
}

%end

// 3. اعتراض الطلبات الفردية وحقن الآبي وتتبعها في السجل
%hook NSMutableURLRequest

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        %orig(sessionAtlantaIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString) {
        [self setValue:sessionAtlantaIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:sessionAtlantaIP forHTTPHeaderField:@"Client-IP"];
        
        NSString *logEntry = [NSString stringWithFormat:@"[%@] %@", sessionAtlantaIP, url.absoluteString];
        if (networkLogs && ![networkLogs containsObject:logEntry]) {
            if ([networkLogs count] > 100) [networkLogs removeObjectAtIndex:0];
            [networkLogs addObject:logEntry];
        }
    }
}

%end
