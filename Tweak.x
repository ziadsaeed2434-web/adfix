#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static BOOL isAlertActive = false;
static BOOL canTriggerAlertFor10 = YES;

// دالة تحديد مسار ملف الـ plist المستقل داخل مجلد Library (خارج مجلد Documents)
NSString *getStandalonePlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AppLockState.plist"];
}

// حفظ بيانات الحظر في الملف المستقل
void saveLockStateToPlist(NSDate *expiryDate) {
    NSString *path = getStandalonePlistPath();
    NSDictionary *dict = @{@"LockExpiryTime": expiryDate};
    [dict writeToFile:path atomically:YES];
}

// التحقق من حالة الحظر عبر قراءة الملف المستقل
BOOL checkLockStateFromPlist(void) {
    NSString *path = getStandalonePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict) {
        NSDate *expiryDate = dict[@"LockExpiryTime"];
        if (expiryDate && [expiryDate isKindOfClass:[NSDate class]]) {
            if ([expiryDate timeIntervalSinceNow] > 0) {
                return YES; // الحظر لا يزال سارياً
            } else {
                // انتهت الـ 10 دقائق، يتم حذف الملف المستقل تلقائياً
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
    }
    return NO;
}

// حذف الملف عند انتهاء المدة
void removeLockStatePlist(void) {
    NSString *path = getStandalonePlistPath();
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

// دالة إظهار التنبيه المانع المستمر
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
            titleLabel.text = @"⚠️ تنبيه الحظر المستمر";
            titleLabel.textColor = [UIColor redColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:18];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 65, alertBox.bounds.size.width - 30, 90)];
            descLabel.text = @"تم الوصول إلى 10 نقاط!\nالتطبيق مقفل مؤقتاً لمدة 10 دقائق.\nمخزن في ملف plist داخل مجلد Library.";
            descLabel.textColor = [UIColor whiteColor];
            descLabel.font = [UIFont systemFontOfSize:12.5];
            descLabel.numberOfLines = 4;
            descLabel.textAlignment = NSTextAlignmentCenter;
            
            [alertBox addSubview:titleLabel];
            [alertBox addSubview:descLabel];
            [blockerView addSubview:alertBox];
            [keyWindow addSubview:blockerView];
            
            // حساب الوقت المتبقي بدقة وإزالة التنبيه عند انتهائه
            NSString *path = getStandalonePlistPath();
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
            NSDate *expiryDate = dict[@"LockExpiryTime"];
            NSTimeInterval remainingTime = expiryDate ? [expiryDate timeIntervalSinceNow] : 600.0;
            if (remainingTime <= 0) remainingTime = 600.0;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *v = [keyWindow viewWithTag:888899];
                if (v) {
                    [v removeFromSuperview];
                }
                removeLockStatePlist();
                isAlertActive = NO;
            });
        }
    });
}

// تحليل الطلبات والتحقق من النقاط بصمت
void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    if (checkLockStateFromPlist()) {
        showPersistentLockoutAlert();
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
                
                if (currentPoints == 10) {
                    if (canTriggerAlertFor10 && !checkLockStateFromPlist()) {
                        canTriggerAlertFor10 = NO;
                        NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:600.0];
                        saveLockStateToPlist(expiry);
                        
                        showPersistentLockoutAlert();
                    }
                } else {
                    canTriggerAlertFor10 = YES;
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
        if (checkLockStateFromPlist()) {
            showPersistentLockoutAlert();
        }
    });
}
