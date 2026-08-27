#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

static UIView *infoBannerView = nil;
static UITextView *bannerLogView = nil;
static NSMutableArray *networkLogs = nil;

// جلب الـ IP المحلي بسرعة فائقة
NSString *getLocalIP() {
    NSString *address = @"غير متوفر";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] ||
                    [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}

// تسجيل أحداث الشبكة
void addNewLog(NSString *log) {
    @synchronized(networkLogs) {
        if (!networkLogs) networkLogs = [NSMutableArray array];
        [networkLogs addObject:log];
        if (networkLogs.count > 30) {
            [networkLogs removeObjectAtIndex:0];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bannerLogView) {
            bannerLogView.text = [networkLogs componentsJoinedByString:@"\n"];
            [bannerLogView scrollRangeToVisible:NSMakeRange(bannerLogView.text.length, 0)];
        }
    });
}

// اعتراض الطلبات
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    @try {
        NSString *urlStr = request.URL.absoluteString;
        NSString *method = request.HTTPMethod;
        NSString *host = request.URL.host;
        
        NSString *log = [NSString stringWithFormat:@"[%@] %@", method, host ? host : urlStr];
        addNewLog(log);
    } @catch (NSException *e) {}
    
    return %orig;
}

%end

// زرع اللوحة الثابتة في أعلى الصفحة الرئيسية للتطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        UIViewController *rootVC = window.rootViewController;
        if (!rootVC) return;
        
        // منع تكرار اللوحة إذا تم إنشاؤها مسبقاً
        if (infoBannerView) return;
        
        // إنشاء لوحة في أعلى الشاشة (ارتفاع 150 بكسل تحت شريط الحالة مباشرة)
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        infoBannerView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, screenWidth, 140)];
        infoBannerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        infoBannerView.layer.borderWidth = 1.0;
        infoBannerView.layer.borderColor = [UIColor greenColor].CGColor;
        infoBannerView.layer.zPosition = 99999; // البقاء في المقدمة
        
        // جلب معرفات الجهاز
        NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        // نص معلومات الجهاز والـ IP
        UILabel *detailsLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 2, screenWidth - 10, 45)];
        detailsLabel.numberOfLines = 3;
        detailsLabel.textColor = [UIColor cyanColor];
        detailsLabel.font = [UIFont systemFontOfSize:9];
        detailsLabel.text = [NSString stringWithFormat:@"IP: %@\nIDFA: %@\nIDFV: %@", getLocalIP(), idfa, idfv];
        [infoBannerView addSubview:detailsLabel];
        
        // صندوق السجلات المصغر داخل اللوحة
        bannerLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 48, screenWidth - 10, 88)];
        bannerLogView.backgroundColor = [UIColor clearColor];
        bannerLogView.textColor = [UIColor whiteColor];
        bannerLogView.editable = NO;
        bannerLogView.font = [UIFont fontWithName:@"Courier" size:9];
        bannerLogView.text = @"جاري مراقبة الشبكة...";
        [infoBannerView addSubview:bannerLogView];
        
        // إضافة اللوحة فوق واجهة التطبيق مباشرة
        [rootVC.view addSubview:infoBannerView];
        [rootVC.view bringSubviewToFront:infoBannerView];
    });
}
