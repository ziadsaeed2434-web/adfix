#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

// بيانات الحسابين
static NSString *const kAccount1UUID = @"5A82BF9F-3EA4-4CA5-AD39-593553C1E15C";
static NSString *const kAccount2UUID = @"2BEE80E4-E20A-432B-879D-A98E2B8BC10D";
static NSString *const kTargetAccountField = @"com.tempnum.virtual-number.deviceUUID";
static NSString *const kKeychainGroup = @"3J96GNXKKU.*";

// مسار حالة الحساب الحالي
NSString *getAccountStatePlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AccountSwitchState.plist"];
}

// دالة لحذف جميع بيانات التطبيق
void eraseAllAppData(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    
    NSArray *directoriesToClean = @[documentsDirectory, libraryDirectory, cachesDirectory];
    for (NSString *dir in directoriesToClean) {
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *file in contents) {
            if ([dir isEqualToString:libraryDirectory] && [file isEqualToString:@"AccountSwitchState.plist"]) {
                continue;
            }
            NSString *fullPath = [dir stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:fullPath error:nil];
        }
    }
    
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
}

// تعديل دالة الـ Keychain لحذف المفتاح بالكامل ثم إعادة إضافته بالقيمة الجديدة
void completelyDeleteAndRecreateKeychain(NSString *uuidString) {
    NSData *passwordData = [uuidString dataUsingEncoding:NSUTF8StringEncoding];
    
    // 1. بناء استعلام البحث وتحديد المفتاح المراد استهدافه
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrAccount] = kTargetAccountField;
#if !TARGET_OS_SIMULATOR
    query[(__bridge id)kSecAttrAccessGroup] = kKeychainGroup;
#endif
    
    // 2. حذف المفتاح من الـ Keychain بالكامل وإزالته جذرياً
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    // 3. إعادة إنشاء وإضافة المفتاح بالـ UUID الجديد تماماً
    NSMutableDictionary *addQuery = [NSMutableDictionary dictionary];
    addQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    addQuery[(__bridge id)kSecAttrAccount] = kTargetAccountField;
    addQuery[(__bridge id)kSecValueData] = passwordData;
#if !TARGET_OS_SIMULATOR
    addQuery[(__bridge id)kSecAttrAccessGroup] = kKeychainGroup;
#endif
    
    OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    if (addStatus != errSecSuccess) {
        // احتياطاً في حال كان النظام يتطلب إضافة بدون مجموعة الوصول
        [addQuery removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
        SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    }
}

// متغير لمنع تكرار فتح النافذة
static BOOL isSwitchAlertActive = NO;

// دالة التبديل الشاملة
void performAccountSwitchAndWipe(void) {
    if (isSwitchAlertActive) return;
    isSwitchAlertActive = YES;
    
    NSString *path = getAccountStatePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSInteger currentAccountIndex = 1;
    
    if (dict && dict[@"AccountIndex"] != nil) {
        currentAccountIndex = [dict[@"AccountIndex"] integerValue];
    }
    
    NSInteger nextAccountIndex = (currentAccountIndex == 1) ? 2 : 1;
    NSString *targetUUID = (nextAccountIndex == 1) ? kAccount1UUID : kAccount2UUID;
    
    // 1. مسح البيانات المؤقتة
    eraseAllAppData();
    
    // 2. حذف مفتاح الـ Keychain بالكامل وإعادة إنشائه بالحساب الجديد
    completelyDeleteAndRecreateKeychain(targetUUID);
    
    // 3. حفظ المؤشر الجديد
    NSDictionary *newState = @{@"AccountIndex": @(nextAccountIndex)};
    [newState writeToFile:path atomically:YES];
    
    // 4. إظهار رسالة التنبيه لإعادة التشغيل
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UISceneWindowScene *windowScene = (UISceneWindowScene *)scene;
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
            UIView *blockerView = [[UIView alloc] initWithFrame:keyWindow.bounds];
            blockerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.85];
            blockerView.userInteractionEnabled = YES;
            
            UIView *alertBox = [[UIView alloc] initWithFrame:CGRectMake(30, keyWindow.bounds.size.height / 2 - 100, keyWindow.bounds.size.width - 60, 200)];
            alertBox.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.98];
            alertBox.layer.cornerRadius = 16;
            alertBox.layer.borderWidth = 1.5;
            alertBox.layer.borderColor = [UIColor systemBlueColor].CGColor;
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, alertBox.bounds.size.width - 30, 30)];
            titleLabel.text = @"🔄 تم الوصول إلى 50 نقطة";
            titleLabel.textColor = [UIColor systemBlueColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:17];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 60, alertBox.bounds.size.width - 30, 110)];
            descLabel.text = [NSString stringWithFormat:@"تم حذف الـ Keychain وإعادة إنشاء الحساب (%ld) بنجاح.\n\nالرجاء إعادة تشغيل التطبيق للتبديل.", (long)nextAccountIndex];
            descLabel.textColor = [UIColor whiteColor];
            descLabel.font = [UIFont systemFontOfSize:14];
            descLabel.numberOfLines = 4;
            descLabel.textAlignment = NSTextAlignmentCenter;
            
            [alertBox addSubview:titleLabel];
            [alertBox addSubview:descLabel];
            [blockerView addSubview:alertBox];
            [keyWindow addSubview:blockerView];
        }
    });
}

// رصد طلبات النقاط
void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
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
                
                // فك الحظر عندما تكون النقاط أقل من 50 (في بداية أي حساب جديد)
                if (currentPoints < 50) {
                    isSwitchAlertActive = NO;
                }
                
                // التبديل عند الوصول إلى 50 نقطة
                if (currentPoints >= 50 && !isSwitchAlertActive) {
                    performAccountSwitchAndWipe();
                }
            }
        }
    }
}

// بروتوكول الاعتراض
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

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}
%end

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
    });
}
