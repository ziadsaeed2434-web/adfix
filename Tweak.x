#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static UITextView *universalLogView = nil;
static UIView *globalOverlayView = nil;
static NSDate *blockUntilDate = nil; 
static BOOL canBlockFor100 = YES; // متغير الحالة للتحكم في التسلسل

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
                universalLogView.text = @"[+] Sequential Points Blocker Active...\n";
                
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

BOOL isNetworkBlocked(void) {
    if (blockUntilDate) {
        NSTimeInterval remaining = [blockUntilDate timeIntervalSinceNow];
        if (remaining > 0) {
            return YES; 
        } else {
            blockUntilDate = nil; 
        }
    }
    return NO;
}

// دالة معالجة الاستجابة وفحص التسلسل المطلوب
void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    if (!url || ![url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
        return;
    }

    NSString *resStr = @"";
    if (data) {
        NSError *jsonError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError && [jsonDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataObj = jsonDict[@"data"];
            NSDictionary *pointsData = dataObj[@"pointsData"];
            NSNumber *pointsVal = pointsData[@"points"];
            
            if (pointsVal) {
                NSInteger currentPoints = [pointsVal integerValue];
                
                if (currentPoints == 100) {
                    // يحظر فقط إذا كانت حالة السماح مفعلة ولم يتم حظره مسبقاً لهذه النقطة
                    if (canBlockFor100 && !isNetworkBlocked()) {
                        blockUntilDate = [NSDate dateWithTimeIntervalSinceNow:600]; // 10 دقائق
                        canBlockFor100 = NO; // قفل الحظر حتى تتغير القيمة لاحقاً
                        showUniversalLog(@"[BLOCKED!] Points = 100. Requests halted for 10 minutes.");
                    }
                } else {
                    // إذا تغيرت القيمة وأصبحت شيئاً آخر (مثل 105 أو أي رقم غير 100)، نعيد تفعيل إمكانية الحظر مستقبلاً
                    canBlockFor100 = YES;
                }
            }
        }
        
        resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!resStr) {
            resStr = [NSString stringWithFormat:@"[Binary Data: %lu bytes]", (unsigned long)data.length];
        } else if (resStr.length > 300) {
            resStr = [[resStr substringToIndex:300] stringByAppendingString:@"...\n(truncated)"];
        }
    } else if (error) {
        resStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    } else {
        resStr = @"[No Body]";
    }
    
    NSString *log = [NSString stringWithFormat:@"[TARGET] [%@] [%@] [%ld] %@\nData: %@", engine, method ?: @"GET", (long)statusCode, url, resStr];
    showUniversalLog(log);
}

// 1. بروتوكول الاعتراض
@interface GodModeNetworkProtocol : NSURLProtocol
@end

@implementation GodModeNetworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (isNetworkBlocked()) {
        return NO; 
    }
    NSString *url = request.URL.absoluteString;
    if (url && [url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
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
    if (isNetworkBlocked()) {
        NSError *blockError = [NSError errorWithDomain:@"NetworkBlockDomain" code:-999 userInfo:@{NSLocalizedDescriptionKey: @"Network blocked due to 100 points limit."}];
        [self.client URLProtocol:self didFailWithError:blockError];
        return;
    }
    
    NSMutableURLRequest *newReq = [self.request mutableCopy];
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

// 2. رصد وحظر طلبات الـ NSURLSession أثناء فترة الحظر
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    if (isNetworkBlocked()) {
        NSError *cancelError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey: @"App network activity paused (10 min block)."}] ;
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, nil, cancelError);
            });
        }
        return %orig(request, ^(NSData *d, NSURLResponse *r, NSError *e){});
    }
    
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

%end

// 3. فرض البروتوكول
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

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        showUniversalLog(@"[Init] Sequential Target Blocker Active.");
    });
}
