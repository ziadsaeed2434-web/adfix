#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static UITextView *universalLogView = nil;
static UIView *globalOverlayView = nil;

// دالة عرض السجلات في النافذة العلوية بشكل فوري ومفصل
void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow) {
            if (!globalOverlayView) {
                CGRect screenBounds = keyWindow.bounds;
                // نافذة سوداء بإطار نيون أخضر مضيء تلتقط كل شيء في الذاكرة والشبكة
                globalOverlayView = [[UIView alloc] initWithFrame:CGRectMake(5, 40, screenBounds.size.width - 10, 270)];
                globalOverlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.99];
                globalOverlayView.layer.cornerRadius = 10;
                globalOverlayView.layer.borderWidth = 1.8;
                globalOverlayView.layer.borderColor = [UIColor greenColor].CGColor;
                globalOverlayView.userInteractionEnabled = YES;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, globalOverlayView.bounds.size.width - 10, globalOverlayView.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor greenColor];
                universalLogView.font = [UIFont fontWithName:@"Courier-Bold" size:7.5];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] God-Mode Network & Memory Interceptor Online (All 10+ Engines Active)...\n";
                
                [globalOverlayView addSubview:universalLogView];
                [keyWindow addSubview:globalOverlayView];
            }
            
            [keyWindow bringSubviewToFront:globalOverlayView];
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    NSString *resStr = @"";
    if (data) {
        resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!resStr) {
            resStr = [NSString stringWithFormat:@"[Binary/Encrypted Data: %lu bytes]", (unsigned long)data.length];
        } else if (resStr.length > 280) {
            resStr = [[resStr substringToIndex:280] stringByAppendingString:@"...\n(truncated)"];
        }
    } else if (error) {
        resStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    } else {
        resStr = @"[No Body / Stream]";
    }
    
    NSString *log = [NSString stringWithFormat:@"[%@] [%@] [%ld] %@\nData: %@", engine, method ?: @"REQ", (long)statusCode, url ?: @"Unknown URL", resStr];
    showUniversalLog(log);
}

// 1. بروتوكول الاعتراض الأعمى للطبقات الدنيا
@interface GodModeNetworkProtocol : NSURLProtocol
@end

@implementation GodModeNetworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    if (url && ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])) {
        if ([NSURLProtocol propertyForKey:@"GodModeHandled" inRequest:request] == nil) {
            return YES;
        }
    }
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:mutableReq];
    return mutableReq;
}
- (void)startLoading {
    NSMutableURLRequest *newReq = [[self.request mutableCopy] autoreleasing];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:newReq];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"Protocol", newReq.HTTPMethod, newReq.URL.absoluteString, httpResp.statusCode, data, error);
        
        if (data) [self.client URLProtocol:self didLoadData:data];
        if (response) [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        if (error) [self.client URLProtocol:self didFailWithError:error];
        else [self.client URLProtocolDidFinishLoading:self];
    }];
    [task resume];
}
- (void)stopLoading {}
@end

// 2. رصد طلبات الـ NSMutableURLRequest والديناميكية لحظة تعديلها
%hook NSMutableURLRequest

- (void)setHTTPBody:(NSData *)HTTPBody {
    %orig;
    if (self.URL && HTTPBody) {
        NSString *bodyStr = [[NSString alloc] initWithData:HTTPBody encoding:NSUTF8StringEncoding] ?: [NSString stringWithFormat:@"[Binary Body: %lu bytes]", (unsigned long)HTTPBody.length];
        showUniversalLog([NSString stringWithFormat:@"[Mutable-Body] %@\nURL: %@\nBody: %@", self.HTTPMethod ?: @"POST", self.URL.absoluteString, bodyStr]);
    }
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    %orig;
    if (self.URL && field && value) {
        // رصد الـ Headers الحساسة والـ Auth Tokens لحظة إضافتها للطلب
        showUniversalLog([NSString stringWithFormat:@"[Header-Inject] %@: %@\nFor URL: %@", field, value, self.URL.absoluteString]);
    }
}

%end

// 3. هوكات مهام NSURLSession الشاملة لكافة الأنواع (Data, Upload, Download)
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    return %orig(url, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession-URL", @"GET", url.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, bodyData, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"UploadTask", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSData *fileData = location ? [NSData dataWithContentsOfURL:location] : nil;
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"DownloadTask", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, fileData, error);
        if (completionHandler) completionHandler(location, response, error);
    });
}

%end

// 4. حقن الإعدادات لفرض البروتوكول على كل الجلسات (بما فيها الخلفية والمعزولة)
%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    NSMutableArray *protocols = [config.protocolClasses mutableCopy];
    if (!protocols) protocols = [NSMutableArray array];
    if (![protocols containsObject:[GodModeNetworkProtocol class]]) {
        [protocols insertObject:[GodModeNetworkProtocol class] atIndex:0];
        config.protocolClasses = protocols;
    }
    return config;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    NSMutableArray *protocols = [config.protocolClasses mutableCopy];
    if (!protocols) protocols = [NSMutableArray array];
    if (![protocols containsObject:[GodModeNetworkProtocol class]]) {
        [protocols insertObject:[GodModeNetworkProtocol class] atIndex:0];
        config.protocolClasses = protocols;
    }
    return config;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *config = %orig;
    NSMutableArray *protocols = [config.protocolClasses mutableCopy];
    if (!protocols) protocols = [NSMutableArray array];
    if (![protocols containsObject:[GodModeNetworkProtocol class]]) {
        [protocols insertObject:[GodModeNetworkProtocol class] atIndex:0];
        config.protocolClasses = protocols;
    }
    return config;
}

%end

// 5. رصد الـ WebViews الداخلية في حال استخدم التطبيق متصفحاً مصغراً لفتح واجهات API أو مصادقة
%hook WKWebView

-قات (void)loadRequest:(NSURLRequest *)request {
    %orig;
    if (request.URL) {
        showUniversalLog([NSString stringWithFormat:@"[WKWebView-Load] GET\nURL: %@", request.URL.absoluteString]);
    }
}

%end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        showUniversalLog(@"[Init] God-Mode Network Interceptor Fully Activated.");
    });
}
