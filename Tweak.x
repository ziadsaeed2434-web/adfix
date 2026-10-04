#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static UITextView *inspectLogView = nil;
static UIView *inspectOverlayView = nil;

void showInspectLog(NSString *logText) {
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
            if (!inspectOverlayView) {
                CGRect screenBounds = keyWindow.bounds;
                inspectOverlayView = [[UIView alloc] initWithFrame:CGRectMake(5, 30, screenBounds.size.width - 10, 420)];
                inspectOverlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.99];
                inspectOverlayView.layer.cornerRadius = 10;
                inspectOverlayView.layer.borderWidth = 2.0;
                inspectOverlayView.layer.borderColor = [UIColor redColor].CGColor;
                inspectOverlayView.userInteractionEnabled = YES;
                
                inspectLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, inspectOverlayView.bounds.size.width - 10, inspectOverlayView.bounds.size.height - 10)];
                inspectLogView.backgroundColor = [UIColor clearColor];
                inspectLogView.textColor = [UIColor greenColor];
                inspectLogView.font = [UIFont fontWithName:@"Courier-Bold" size:6.5];
                inspectLogView.editable = NO;
                inspectLogView.text = @"[+] Ultimate Inspector & Tracker Online (All Screens, Clicks & Network)...\n";
                
                [inspectOverlayView addSubview:inspectLogView];
                [keyWindow addSubview:inspectOverlayView];
            }
            
            [keyWindow bringSubviewToFront:inspectOverlayView];
            
            if (inspectLogView) {
                NSString *oldText = inspectLogView.text;
                inspectLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// دالة مساعدة لطباعة أحداث الشبكة
void logNetworkEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    NSString *resStr = @"";
    if (data) {
        resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!resStr) {
            resStr = [NSString stringWithFormat:@"[Binary Data: %lu bytes]", (unsigned long)data.length];
        } else if (resStr.length > 200) {
            resStr = [[resStr substringToIndex:200] stringByAppendingString:@"...\n(truncated)"];
        }
    } else if (error) {
        resStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    } else {
        resStr = @"[No Body]";
    }
    
    NSString *log = [NSString stringWithFormat:@"[NET-%@] [%@] [%ld] %@\nData: %@", engine, method ?: @"REQ", (long)statusCode, url ?: @"Unknown URL", resStr];
    showInspectLog(log);
}

// 1. بروتوكول شبكة الأمان الشامل (GodMode)
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
    NSMutableURLRequest *newReq = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:newReq];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logNetworkEvent(@"Protocol", newReq.HTTPMethod, newReq.URL.absoluteString, httpResp.statusCode, data, error);
        
        if (data) [self.client URLProtocol:self didLoadData:data];
        if (response) [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        if (error) [self.client URLProtocol:self didFailWithError:error];
        else [self.client URLProtocolDidFinishLoading:self];
    }];
    [task resume];
}
- (void)stopLoading {}
@end

// 2. رصد طلبات الـ NSURLSession
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logNetworkEvent(@"Session", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

%end

// 3. فرض بروتوكول الشبكة
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

%end

// 4. رصد شامل لكل الشاشات (ViewControllers & SwiftUI Hosting Controllers)
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    NSString *vcName = NSStringFromClass([self class]);
    showInspectLog([NSString stringWithFormat:@"[VC-Load] 📱 Loaded Screen: %@", vcName]);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *vcName = NSStringFromClass([self class]);
    showInspectLog([NSString stringWithFormat:@"[VC-Appear] 👀 Active Screen: %@", vcName]);
}

%end

// 5. رصد النقرات والأزرار التقليدية (UIControl)
%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    %orig;
    NSString *targetClass = NSStringFromClass([target class]);
    NSString *actionStr = NSStringFromSelector(action);
    showInspectLog([NSString stringWithFormat:@"[Click] 🖱️ Target: %@ | Action: %@", targetClass, actionStr]);
}

%end

// 6. رصد أي نقرة لمس عامة على الشاشة (حتى أزرار SwiftUI والتفاعلات التي لا تمر عبر UIControl)
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    %orig;
    if (event.type == UIEventTypeTouches) {
        NSSet *allTouches = [event allTouches];
        for (UITouch *touch in allTouches) {
            if (touch.phase == UITouchPhaseBegan) {
                CGPoint loc = [touch locationInView:self];
                UIView *hitView = [self hitTest:loc withEvent:event];
                NSString *viewClass = NSStringFromClass([hitView class]);
                if ([viewClass containsString:@"Button"] || [viewClass containsString:@"Control"] || [viewClass containsString:@"Hosting"] || [viewClass containsString:@"Cell"]) {
                    showInspectLog([NSString stringWithFormat:@"[Touch] 👆 Tap on View: %@ at (%.0f, %.0f)", viewClass, loc.x, loc.y]);
                }
            }
        }
    }
}

%end

// 7. رصد صفحات الويب (WKWebView)
%hook WKWebView

- (void)loadRequest:(NSURLRequest *)request {
    %orig;
    if (request.URL) {
        showInspectLog([NSString stringWithFormat:@"[WebView] 🌐 Loading URL: %@", request.URL.absoluteString]);
    }
}

%end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        showInspectLog([NSString stringWithFormat:@"[Init] Ultimate Inspector Ready! Go use the app."]);
    });
}
