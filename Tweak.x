#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static UITextView *universalLogView = nil;
static UIView *globalOverlayView = nil;
static BOOL isAlertActive = false;
static BOOL canTriggerAlertFor10 = YES;

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
                universalLogView.text = @"[+] Persistent 10-Min Lockout Guard Active...\n";
                
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

// دالة التحقق مما إذا كان وقت الحظر لا يزال سارياً (محفوظ في الذاكرة الدائمة)
BOOL isLockoutStillActive(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *expiryDate = [defaults objectForKey:@"AppLockoutExpiryDate"];
    if (expiryDate) {
        if ([expiryDate timeIntervalSinceNow] > 0) {
            return YES; // الحظر ساري حتى لو خرجت من التطبيق ورجعت
        } else {
            [defaults removeObjectForKey:@"AppLockoutExpiryDate"]; // انتهت الـ 10 دقائق
        }
    }
    return NO;
}

// دالة إظهار التنبيه المانع بشكل دائم طوال الـ 10 دقائق
void showPersistentLockoutAlert(void) {
    if (isAlertActive) return;
    isAlertActive = YES;
    
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
            // إزالة أي تنبيه قديم قد يكون موجوداً لعدم التكرار
            UIView *oldBlocker = [keyWindow viewWithTag:888899];
            if (oldBlocker) [oldBlocker removeFromSuperview];
            
            UIView *blockerView = [[UIView alloc] initWithFrame:keyWindow.bounds];
            blockerView.tag = 888899;
            blockerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.75];
            blockerView.userInteractionEnabled = YES; // يمنع النقر تماماً على ما خلفه
            
            UIView *alertBox = [[UIView alloc] initWithFrame:CGRectMake(30, keyWindow.bounds.size.height / 2 - 110, keyWindow.bounds.size.width - 60, 220)];
            alertBox.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.98];
            alertBox.layer.cornerRadius = 16;
            alertBox.layer.borderWidth = 1.5;
            alertBox.layer.borderColor = [UIColor redColor].CGColor;
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, alertBox.bounds.size.width - 30, 30)];
            titleLabel.text = @"⚠️ تنبيه الحظر المستمر";
            titleLabel.textColor = [UIColor redColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:18];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 65, alertBox.bounds.size.width - 30, 90)];
            descLabel.text = @"تم الوصول إلى 10 نقاط!\nالتطبيق مقفل مؤقتاً لمدة 10 دقائق.\nحتى لو خرجت وعجست للتطبيق سيبقى التنبيه حتى تنتهي المدة.";
            descLabel.textColor = [UIColor whiteColor];
            descLabel.font = [UIFont systemFontOfSize:12.5];
            descLabel.numberOfLines = 4;
            descLabel.textAlignment = NSTextAlignmentCenter;
            
            [alertBox addSubview:titleLabel];
            [alertBox addSubview:descLabel];
            [blockerView addSubview:alertBox];
            [keyWindow addSubview:blockerView];
            
            showUniversalLog(@"[PERSISTENT ALERT SHOWN] Lockout active and saved.");
            
            // حساب الوقت المتبقي بدقة وإزالة التنبيه تلقائياً فور انتهائه
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDate *expiryDate = [defaults objectForKey:@"AppLockoutExpiryDate"];
            NSTimeInterval remainingTime = expiryDate ? [expiryDate timeIntervalSinceNow] : 600.0;
            if (remainingTime <= 0) remainingTime = 600.0;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *v = [keyWindow viewWithTag:888899];
                if (v) {
                    [v removeFromSuperview];
                }
                [defaults removeObjectForKey:@"AppLockoutExpiryDate"];
                isAlertActive = NO;
                showUniversalLog(@"[ALERT DISMISSED] 10 minutes lockout expired.");
            });
        }
    });
}

// دالة تحليل الطلبات وفحص شرط الـ 10 نقاط
void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    // إذا كان الحظر سارياً بالفعل (حتى لو أغلق التطبيق وفتحه مجدداً)، أظهر التنبيه فوراً
    if (isLockoutStillActive()) {
        showPersistentLockoutAlert();
    }

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
                
                if (currentPoints == 10) {
                    if (canTriggerAlertFor10 && !isLockoutStillActive()) {
                        canTriggerAlertFor10 = NO;
                        // حفظ وقت انتهاء الحظر (بعد 10 دقائق من الآن) في الذاكرة الدائمة
                        NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:600.0];
                        [[NSUserDefaults standardUserDefaults] setObject:expiry forKey:@"AppLockoutExpiryDate"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        showPersistentLockoutAlert();
                    }
                } else {
                    canTriggerAlertFor10 = YES;
                }
            }
        }
        
        resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!resStr) {
            resStr = [NSString stringWithFormat:@"[Binary/Encrypted Data: %lu bytes]", (unsigned long)data.length];
        } else if (resStr.length > 500) {
            resStr = [[resStr substringToIndex:500] stringByAppendingString:@"...\n(truncated)"];
        }
    } else if (error) {
        resStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    } else {
        resStr = @"[No Body / Stream]";
    }
    
    NSString *log = [NSString stringWithFormat:@"[TARGET FOUND!] [%@] [%@] [%ld] %@\nData: %@", engine, method ?: @"GET", (long)statusCode, url, resStr];
    showUniversalLog(log);
}

// 1. بروتوكول الاعتراض للطبقات الدنيا
@interface GodModeNetworkProtocol : NSURLProtocol
@end

@implementation GodModeNetworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
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

// 2. رصد طلبات الـ NSURLSession المستهدفة
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

%end

// 3. فرض البروتوكول على الإعدادات
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
        // فحص حالة الحظر فور فتح التطبيق
        if (isLockoutStillActive()) {
            showPersistentLockoutAlert();
        }
        showUniversalLog(@"[Init] Persistent 10-Min Lockout Interceptor Active.");
    });
}
