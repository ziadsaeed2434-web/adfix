#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

// متغيرات لتخزين الموقع والـ IP اليوناني للجلسة الحالية
static double greeceLat = 0.0;
static double greeceLon = 0.0;
static NSString *greeceFakeIP = nil;

// مصفوفة لتسجيل الروابط والطلبات الصادرة
static NSMutableArray *networkLogs = nil;

// نافذة خاصة بالزر لتكون ثابتة ولا تختفي أبداً
static UIWindow *floatingWindow = nil;

// دالة توليد بيانات اليونان لكل إقلاع
void generateGreeceRandomSession() {
    greeceLat = 35.0 + ((double)arc4random_uniform(600) / 100.0);
    greeceLon = 20.0 + ((double)arc4random_uniform(600) / 100.0);
    
    NSArray *greeceIPPrefixes = @[@"79.129", @"212.251", @"81.18", @"94.64", @"188.4"];
    NSString *prefix = greeceIPPrefixes[arc4random_uniform((uint32_t)greeceIPPrefixes.count)];
    int ip3 = arc4random_uniform(200) + 10;
    int ip4 = arc4random_uniform(200) + 10;
    greeceFakeIP = [NSString stringWithFormat:@"%@.%d.%d", prefix, ip3, ip4];
    
    networkLogs = [[NSMutableArray alloc] init];
}

// كلاس إدارة الزر والنافذة العائمة
@interface DebugMenuManager : NSObject
+ (void)showDebugInfo;
+ (void)createFloatingButtonWindow;
@end

@implementation DebugMenuManager

+ (void)showDebugInfo {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    NSString *logsText = @"";
    if (networkLogs.count > 0) {
        NSInteger startIndex = MAX(0, (NSInteger)networkLogs.count - 5);
        NSArray *recentLogs = [networkLogs subarrayWithRange:NSMakeRange(startIndex, networkLogs.count - startIndex)];
        logsText = [recentLogs componentsJoinedByString:@"\n\n"];
    } else {
        logsText = @"لا توجد طلبات مسجلة بعد.";
    }
    
    NSString *message = [NSString stringWithFormat:@"📍 الموقع الحالي (اليونان):\nLat: %.4f, Lon: %.4f\n\n🌐 الـ IP الحالي:\n%@\n\n📦 آخر الطلبات الصادرة:\n%@", greeceLat, greeceLon, greeceFakeIP, logsText];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔍 لوحة معلومات التويك" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    
    [topController presentViewController:alert animated:YES completion:nil];
}

+ (void)createFloatingButtonWindow {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (floatingWindow) return;
        
        floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 60, 60)];
        floatingWindow.windowLevel = UIWindowLevelAlert + 1;
        floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        floatingWindow.rootViewController = vc;
        
        UIButton *floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 60, 60);
        floatButton.backgroundColor = [UIColor systemBlueColor];
        [floatButton setTitle:@"🌐" forState:UIControlStateNormal];
        floatButton.titleLabel.font = [UIFont systemFontOfSize:24];
        floatButton.layer.cornerRadius = 30;
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowRadius = 4.0;
        floatButton.layer.shadowOpacity = 0.6;
        
        [floatButton addTarget:self action:@selector(showDebugInfo) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:floatButton];
        [floatingWindow makeKeyAndVisible];
    });
}

@end

// تنفيذ الإعدادات فور الإقلاع
%ctor {
    generateGreeceRandomSession();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [DebugMenuManager createFloatingButtonWindow];
    });
}

// ---------------------------------------------------------
// 1. خداع الموقع الجغرافي (GPS) حصراً في اليونان
// ---------------------------------------------------------
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(greeceLat, greeceLon);
}

- (CLLocationAccuracy)horizontalAccuracy { return 5.0; }
- (CLLocationAccuracy)verticalAccuracy { return 5.0; }

%end

%hook CLLocationManager

- (void)startUpdatingLocation {
    %orig;
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:greeceLat longitude:greeceLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}

%end

// ---------------------------------------------------------
// 2. خداع الشبكة وتتبع الطلبات الصادرة (تم تصحيح صيغة الدالة)
// ---------------------------------------------------------
%hook NSURLConnection

+ (NSData * _Nullable)sendSynchronousRequest:(NSURLRequest * _Nonnull)request returningResponse:(NSURLResponse * _Nullable * _Nullable)response error:(NSError * _Nullable * _Nullable)error {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    [mutableReq setValue:greeceFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:greeceFakeIP forHTTPHeaderField:@"Client-IP"];
    
    if (mutableReq.URL.absoluteString) {
        NSString *logEntry = [NSString stringWithFormat:@"🔗 [%@] \nURL: %@", greeceFakeIP, mutableReq.URL.absoluteString];
        if (networkLogs && ![networkLogs containsObject:logEntry]) {
            [networkLogs addObject:logEntry];
        }
    }
    
    return %orig(mutableReq, response, error);
}

%end
