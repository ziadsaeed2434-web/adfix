#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITextView *universalLogView = nil;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
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
            UIView *overlay = [keyWindow viewWithTag:999888];
            if (!overlay) {
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 30, keyWindow.bounds.size.width - 20, 380)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:7.5];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] FLEX-Style Ultimate Network Interceptor Active...\n";
                
                [overlay addSubview:universalLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// ==========================================
// 1. بروتوكول الاعتراض الشامل (طريقة FLEX الأساسية)
// ==========================================
@interface FLEXStyleNetworkProtocol : NSURLProtocol
@end

@implementation FLEXStyleNetworkProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *urlStr = [request.URL absoluteString];
    if ([urlStr containsString:@"127.0.0.1"] || [urlStr containsString:@"localhost"]) {
        return NO;
    }
    // منع تكرار المعالجة لنفس الطلب
    if ([NSURLProtocol propertyForKey:@"FLEXHandledKey" inRequest:request]) {
        return NO;
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *mutableReq = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"FLEXHandledKey" inRequest:mutableReq];
    
    NSString *urlStr = [mutableReq.URL absoluteString] ?: @"<Unknown>";
    NSString *method = mutableReq.HTTPMethod ?: @"GET";
    
    // استخراج الـ Headers تماماً مثل الصورة
    NSDictionary *headers = mutableReq.allHTTPHeaderFields;
    NSMutableString *headersStr = [NSMutableString string];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [headersStr appendFormat:@"  %@: %@\n", key, obj];
    }];
    
    // استخراج الـ Request Body إن وجد
    NSData *bodyData = mutableReq.HTTPBody;
    NSString *reqBodyStr = @"<None>";
    if (bodyData) {
        reqBodyStr = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        if (!reqBodyStr) reqBodyStr = [NSString stringWithFormat:@"<Binary Size: %lu>", (unsigned long)bodyData.length];
        if (reqBodyStr.length > 150) reqBodyStr = [reqBodyStr substringToIndex:150];
    }
    
    // تنفيذ الطلب عبر الجلسة الحية لضمان عدم تعطل التطبيق
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:mutableReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        NSInteger statusCode = [httpResp statusCode];
        
        NSString *respBodyStr = @"<No Data>";
        if (data) {
            respBodyStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!respBodyStr) respBodyStr = [NSString stringWithFormat:@"<Binary Size: %lu>", (unsigned long)data.length];
            if (respBodyStr.length > 300) respBodyStr = [respBodyStr substringToIndex:300];
        } else if (error) {
            respBodyStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
        }
        
        // تنسيق السجل ليطابق بيانات أداة الفحص (FLEX / الصورة)
        NSString *log = [NSString stringWithFormat:@"[FLEX Intercept]\nURL: %@\nMethod: %@\nStatus: %ld\nMechanism: NSURLSessionDataTask (Alamofire)\n[Headers]:\n%@[ReqBody]: %@\n[Response Body]:\n%@", 
                         urlStr, 
                         method, 
                         (long)statusCode, 
                         headersStr.length > 0 ? headersStr : @"  <None>\n", 
                         reqBodyStr, 
                         respBodyStr];
        
        showUniversalLog(log);
        
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
        } else {
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }] resume];
}

- (void)stopLoading {}

@end

// ==========================================
// 2. خطافات NSURLSession لضمان تغطية طلبات Alamofire المباشرة
// ==========================================
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *url = [request.URL absoluteString] ?: @"<Unknown>";
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        NSString *respStr = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<No Data>";
        if (respStr.length > 250) respStr = [respStr substringToIndex:250];
        
        NSString *log = [NSString stringWithFormat:@"[Alamofire/Session] URL: %@\nStatus: %ld\nResponse: %@", url, (long)[httpResp statusCode], respStr];
        showUniversalLog(log);
        
        if (completionHandler) completionHandler(data, response, error);
    };
    return %orig(request, wrappedHandler);
}

%end

// ==========================================
// 3. تفعيل نظام الاعتراض العام تلقائياً
// ==========================================
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[FLEXStyleNetworkProtocol class]];
        showUniversalLog(@"[+] FLEX-Style Network Protocol Registered!");
    });
}
