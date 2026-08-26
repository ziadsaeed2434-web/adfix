#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <CoreLocation/CoreLocation.h>

// مدير السجل الشامل على الشاشة
@interface FullInspector : NSObject
+ (instancetype)sharedInstance;
- (void)logEvent:(NSString *)eventText;
@end

@implementation FullInspector {
    UITextView *_textView;
    UIWindow *_inspectorWindow;
    UIView *_containerView;
}

+ (instancetype)sharedInstance {
    static FullInspector *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[FullInspector alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            
            // نافذة تغطي جزءاً كبيراً من الشاشة لتتمكن من القراءة بوضوح
            self->_inspectorWindow = [[UIWindow alloc] initWithFrame:CGRectMake(10, 50, screenBounds.size.width - 20, 320)];
            self->_inspectorWindow.windowLevel = UIWindowLevelAlert + 9999;
            self->_inspectorWindow.hidden = NO;
            self->_inspectorWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
            self->_inspectorWindow.layer.cornerRadius = 14;
            self->_inspectorWindow.layer.borderWidth = 1.5;
            self->_inspectorWindow.layer.borderColor = [UIColor cyanColor].CGColor;
            self->_inspectorWindow.layer.masksToBounds = YES;
            
            UIViewController *vc = [[UIViewController alloc] init];
            vc.view.backgroundColor = [UIColor clearColor];
            self->_inspectorWindow.rootViewController = vc;
            
            // شاشة النصوص القابلة للتمرير
            self->_textView = [[UITextView alloc] initWithFrame:CGRectMake(5, 35, screenBounds.size.width - 30, 275)];
            self->_textView.backgroundColor = [UIColor clearColor];
            self->_textView.textColor = [UIColor cyanColor];
            self->_textView.font = [UIFont fontWithName:@"Courier" size:10];
            self->_textView.editable = NO;
            self->_textView.text = @"[FullInspector] App Started. Monitoring everything...\n";
            [vc.view addSubview:self->_textView];
            
            // زر نسخ السجل
            UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            copyBtn.frame = CGRectMake(10, 5, 80, 25);
            [copyBtn setTitle:@"COPY LOGS" forState:UIControlStateNormal];
            [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyBtn.backgroundColor = [UIColor darkGrayColor];
            copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
            copyBtn.layer.cornerRadius = 5;
            [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
            [vc.view addSubview:copyBtn];
            
            // زر إخفاء/تصغير النافذة
            UIButton *hideBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            hideBtn.frame = CGRectMake(screenBounds.size.width - 100, 5, 75, 25);
            [hideBtn setTitle:@"HIDE/SHOW" forState:UIControlStateNormal];
            [hideBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            hideBtn.backgroundColor = [UIColor darkGrayColor];
            hideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
            hideBtn.layer.cornerRadius = 5;
            [hideBtn addTarget:self action:@selector(toggleWindow) forControlEvents:UIControlEventTouchUpInside];
            [vc.view addSubview:hideBtn];
        });
    }
    return self;
}

- (void)logEvent:(NSString *)eventText {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_textView) {
            NSString *current = self->_textView.text;
            self->_textView.text = [NSString stringWithFormat:@"%@\n------------------\n%@", eventText, current];
            if (self->_textView.text.length > 8000) {
                self->_textView.text = [self->_textView.text substringToIndex:8000];
            }
        }
    });
}

- (void)copyLogs {
    UIPasteboard.generalPasteboard.string = self->_textView.text;
    [[FullInspector sharedInstance] logEvent:@"[INFO] Logs copied to clipboard!"];
}

- (void)toggleWindow {
    self->_inspectorWindow.hidden = !self->_inspectorWindow.hidden;
}

@end

// بدء المراقبة فور تشغيل التطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FullInspector sharedInstance] logEvent:@"[AppLaunch] Initialized successfully."];
    });
}

// 1. مراقبة طلبات الشبكة بالكامل (الروابط، الاستجابة، الأخطاء)
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = request.URL.absoluteString;
    
    // تسجيل أي رابط يمر بالشبكة
    [[FullInspector sharedInstance] logEvent:[NSString stringWithFormat:@"[NET REQ] Method: %@\nURL: %@", request.HTTPMethod, urlString]];
    
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (error) {
            [[FullInspector sharedInstance] logEvent:[NSString stringWithFormat:@"[NET ERR] %@", error.localizedDescription]];
        } else {
            NSString *respBody = @"";
            if (data && data.length < 300) {
                respBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[Binary Data]";
            } else {
                Mo: respBody = [NSString stringWithFormat:@"[Data size: %lu bytes]", (unsigned long)data.length];
            }
            [[FullInspector sharedInstance] logEvent:[NSString stringWithFormat:@"[NET RESP] Code:ld\nBody: %@", (long)httpResp.statusCode, respBody]];
        }
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    
    return %orig(request, wrappedHandler);
}
%end

// 2. مراقبة معرفات الجهاز (متى يطلب التطبيق الـ IDFA أو UDID)
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSUUID *val = %orig;
    [[FullInspector sharedInstance] logEvent:[NSString stringWithFormat:@"[HOOK] ASIdentifierManager requested IDFA -> %@", val.UUIDString]];
    return val;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    NSUUID *val = %orig;
    [[FullInspector sharedInstance] logEvent:[NSString stringWithFormat:@"[HOOK] UIDevice requested IDFV -> %@", val.UUIDString]];
    return val;
}
%end

// 3. مراقبة الموقع الجغرافي
%hook CLLocationManager
- (void)startUpdatingLocation {
    [[FullInspector sharedInstance] logEvent:@"[HOOK] CLLocationManager requested GPS Location update."];
    %orig;
}
%end
