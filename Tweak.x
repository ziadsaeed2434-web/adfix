#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق
#define TARGET_POINTS 20
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL_PATH @"/api/v1/users/additional/points/data"

// دالة آمنة لجلب النافذة (يجب استدعاؤها من الـ Main Thread فقط)
UIWindow *getSafelyKeyWindow() {
    UIWindow *foundWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        foundWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!foundWindow) {
        foundWindow = [UIApplication sharedApplication].keyWindow;
    }
    return foundWindow;
}

// دالة عرض شاشة الحظر (آمنة تماماً)
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;
        
        // منع تكرار الشاشة
        if ([keyWindow viewWithTag:9999]) return;
        
        UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
        overlay.tag = 9999;
        overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
        overlay.userInteractionEnabled = YES;
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, keyWindow.bounds.size.width - 40, 40)];
        titleLabel.text = @"توقف مؤقت للتطبيق";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:26];
        [overlay addSubview:titleLabel];
        
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 280, keyWindow.bounds.size.width - 40, 80)];
        descLabel.text = @"لقد وصلت إلى 20 نقطة.\nسيتوقف التطبيق لمدة 10 دقائق تلقائياً.";
        descLabel.textColor = [UIColor lightGrayColor];
        descLabel.textAlignment = NSTextAlignmentCenter;
        descLabel.numberOfLines = 3;
        descLabel.font = [UIFont systemFontOfSize:16];
        [overlay addSubview:descLabel];
        
        [keyWindow addSubview:overlay];
        [keyWindow bringSubviewToFront:overlay];
    });
}

// دالة تحليل البيانات وفحص النقاط
void parseAndCheckData(NSData *data) {
    if (!data) return;
    
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (!jsonError && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        NSDictionary *dataDict = dict[@"data"];
        
        if ([dataDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *pointsData = dataDict[@"pointsData"];
            if ([pointsData isKindOfClass:[NSDictionary class]]) {
                NSNumber *pointsNum = pointsData[@"points"];
                
                if (pointsNum) {
                    NSInteger points = [pointsNum integerValue];
                    
                    // الشرط: 20 نقطة أو أكثر
                    if (points >= TARGET_POINTS) {
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
                        
                        if (blockEndTime == 0 || blockEndTime <= now) {
                            blockEndTime = now + BLOCK_DURATION;
                            [defaults setDouble:blockEndTime forKey:KEY_BLOCK_END];
                            [defaults synchronize];
                        }
                        
                        showBlockOverlay();
                    }
                }
            }
        }
    }
}

// 1. اعتراض مهام البيانات في NSURLSession فقط (بدون NSJSONSerialization لتجنب الكراش)
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = request.URL.absoluteString;
    if (urlString && [urlString containsString:TARGET_URL_PATH]) {
        void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            parseAndCheckData(data);
            if (completionHandler) {
                completionHandler(data, response, error);
            }
        };
        return %orig(request, wrappedHandler);
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = url.absoluteString;
    if (urlString && [urlString containsString:TARGET_URL_PATH]) {
        void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            parseAndCheckData(data);
            if (completionHandler) {
                completionHandler(data, response, error);
            }
        };
        return %orig(url, wrappedHandler);
    }
    return %orig(url, completionHandler);
}

%end

// 2. التهيئة ومراقبة حالة التطبيق (آمنة تماماً)
%ctor {
    // تأخير الفحص الأولي لمدة ثانيتين لضمان اكتمال إقلاع التطبيق
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    });

    // مراقبة العودة من الخلفية
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    }];
}
