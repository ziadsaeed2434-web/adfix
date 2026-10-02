#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static BOOL isAlertActive = false;
static NSTimer *virtualClockTimer = nil;

// مسار ملف الساعة الافتراضية داخل مجلد Library
NSString *getVirtualClockPlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AppLockState.plist"];
}

// التحقق مما إذا كان مسموحاً بالحظر
BOOL isArmedFor395(void) {
    NSString *path = getVirtualClockPlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict && dict[@"IsArmed"] != nil) {
        return [dict[@"IsArmed"] boolValue];
    }
    return YES;
}

// فحص الساعة الافتراضية (تعمل بدقة سواء بالداخل أو بعد إغلاق التطبيق نهائياً)
BOOL checkVirtualClockState(void) {
    NSString *path = getVirtualClockPlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict) {
        NSDate *expiryDate = dict[@"VirtualExpiryTime"];
        if (expiryDate && [expiryDate isKindOfClass:[NSDate class]]) {
            if ([expiryDate timeIntervalSinceNow] > 0) {
                return YES; // الحظر افتراضياً لا يزال سارياً
            } else {
                // انتهى الوقت تماماً (سواء كنت بالداخل أو فتحت التطبيق بعد إغلاقه)
                NSMutableDictionary *mutableDict = [dict mutableCopy];
                [mutableDict removeObjectForKey:@"VirtualExpiryTime"];
                mutableDict[@"IsArmed"] = @NO;
                [mutableDict writeToFile:path atomically:YES];
            }
        }
    }
    return NO;
}

// بدء الساعة الافتراضية وحفظ وقت انتهائها المطلق
void startVirtualClockLock(NSDate *expiryDate) {
    NSString *path = getVirtualClockPlistPath();
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!mutableDict) {
        mutableDict = [NSMutableDictionary dictionary];
    }
    mutableDict[@"VirtualExpiryTime"] = expiryDate;
    mutableDict[@"IsArmed"] = @NO;
    [mutableDict writeToFile:path atomically:YES];
}

// إعادة تفعيل النظام لرؤية رقم غير 395
void armVirtualClockAgain(void) {
    NSString *path = getVirtualClockPlistPath();
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!mutableDict) {
        mutableDict = [NSMutableDictionary dictionary];
    }
    mutableDict[@"IsArmed"] = @YES;
    [mutableDict writeToFile:path atomically:YES];
}

// إيقاف وإزالة واجهة الحظر الافتراضية فوراً
void dismissVirtualLockoutAlert(void) {
    if (virtualClockTimer) {
        [virtualClockTimer invalidate];
        virtualClockTimer = nil;
    }
    
    NSString *path = getVirtualClockPlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSMutableDictionary *mutableDict = [dict mutableCopy];
    if (mutableDict) {
        [mutableDict removeObjectForKey:@"VirtualExpiryTime"];
        mutableDict[@"IsArmed"] = @NO;
        [mutableDict writeToFile:path atomically:YES];
    }
    
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
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        
        if (keyWindow) {
            UIView *v = [keyWindow viewWithTag:888899];
            if (v) {
                [v removeFromSuperview];
            }
        }
        isAlertActive = NO;
    });
}

// إظهار واجهة التنبيه للساعة الافتراضية مع العد التنازلي الحي
void showVirtualLockoutAlert(void) {
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
            UIView *oldBlocker = [keyWindow viewWithTag:888899];
            if (oldBlocker) [oldBlocker removeFromSuperview];
            
            UIView *blockerView = [[UIView alloc] initWithFrame:keyWindow.bounds];
            blockerView.tag = 888899;
            blockerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.75];
            blockerView.userInteractionEnabled = YES;
            
            UIView *alertBox = [[UIView alloc] initWithFrame:CGRectMake(30, keyWindow.bounds.size.height / 2 - 110, keyWindow.bounds.size.width - 60, 220)];
            alertBox.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.98];
            alertBox.layer.cornerRadius = 16;
            alertBox.layer.borderWidth = 1.5;
            alertBox.layer.borderColor = [UIColor redColor].CGColor;
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, alertBox.bounds.size.width - 30, 30)];
            titleLabel.text = @"⚠️ الساعة الافتراضية للحظر";
            titleLabel.textColor = [UIColor redColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:18];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 65, alertBox.bounds.size.width - 30, 90)];
            descLabel.text = @"تم الوصول إلى 395 نقطة!\nالتطبيق مقفل بواسطة الساعة الافتراضية لمدة 10 دقائق.\nسيختفي الحظر تلقائياً في كل الظروف.";
            descLabel.tag = 999911;
            descLabel.textColor = [UIColor whiteColor];
            descLabel.font = [UIFont systemFontOfSize:12.5];
            descLabel.numberOfLines = 4;
            descLabel.textAlignment = NSTextAlignmentCenter;
            
            [alertBox addSubview:titleLabel];
            [alertBox addSubview:descLabel];
            [blockerView addSubview:alertBox];
            [keyWindow addSubview:blockerView];
            
            if (virtualClockTimer) {
                [virtualClockTimer invalidate];
                virtualClockTimer = nil;
            }
            
            // نبضة الساعة الافتراضية داخل التطبيق
            virtualClockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                if (!checkVirtualClockState()) {
                    dismissVirtualLockoutAlert();
                } else {
                    NSString *path = getVirtualClockPlistPath();
                    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
                    NSDate *expiryDate = dict[@"VirtualExpiryTime"];
                    if (expiryDate) {
                        NSInteger remaining = (NSInteger)[expiryDate timeIntervalSinceNow];
                        if (remaining < 0) remaining = 0;
                        NSInteger minutes = remaining / 60;
                        NSInteger seconds = remaining % 60;
                        UILabel *dLabel = [blockerView viewWithTag:999911];
                        if (dLabel) {
                            dLabel.text = [NSString stringWithFormat:@"تم الوصول إلى 395 نقطة!\nالتطبيق مقفل بواسطة الساعة الافتراضية.\nالوقت المتبقي: %02ld:%02ld دقيقة", (long)minutes, (long)seconds];
                        }
                    }
                }
            }];
        }
    });
}

// تحليل الطلبات والتحقق من النقاط بصمت
void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    if (checkVirtualClockState()) {
        showVirtualLockoutAlert();
        return;
    } else {
        if (isAlertActive) {
            dismissVirtualLockoutAlert();
        }
    }

    if (!url || ![url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
        return;
    }

    if (data) {
        NSError *jsonError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError && [jsonDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataObj = jsonDict[@"data"];
            NSDictionary *pointsData = dataObj[@"pointsData"];
            NSNumber *pointsVal = pointsData[@"points"];
            
            if (pointsVal) {
                NSInteger currentPoints = [pointsVal integerValue];
                
                if (currentPoints == 395) {
                    if (isArmedFor395() && !checkVirtualClockState()) {
                        // تشغيل الساعة الافتراضية لمدة 10 دقائق كاملة (600 ثانية) عند الوصول لـ 395 نقطة
                        NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:600.0];
                        startVirtualClockLock(expiry);
                        showVirtualLockoutAlert();
                    }
                } else {
                    armVirtualClockAgain();
                }
            }
        }
    }
}

// 1. بروتوكول الاعتراض
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

// 2. رصد طلبات NSURLSession
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
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
        
        // التحقق الفوري من الساعة الافتراضية عند تشغيل التطبيق (حتى لو أغلقته تماماً وفتشته لاحقاً)
        if (checkVirtualClockState()) {
            showVirtualLockoutAlert();
        }
        
        // فحص الساعة الافتراضية فور العودة للتطبيق من الخلفية
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (checkVirtualClockState()) {
                showVirtualLockoutAlert();
            } else {
                dismissVirtualLockoutAlert();
            }
        }];
    });
}
