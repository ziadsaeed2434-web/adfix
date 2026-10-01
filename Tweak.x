#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // النقاط المستهدفة
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL_PATH @"/api/v1/users/additional/points/data"

// دالة آمنة لجلب النافذة النشطة لمنع الـ Crash
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

// دالة عرض شاشة الحظر الإجباري المانعة للتفاعل بأمان تام
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (keyWindow) {
            // إذا كانت الشاشة موجودة مسبقاً، نرفعها للأعلى فقط
            UIView *existingOverlay = [keyWindow viewWithTag:9999];
            if (existingOverlay) {
                [keyWindow bringSubviewToFront:existingOverlay];
                return;
            }
            
            UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
            overlay.tag = 9999;
            overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
            overlay.userInteractionEnabled = YES; // يمنع النقر على أي شيء خلفه
            
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
        }
    });
}

// دالة لفحص البيانات وتحليل الـ JSON واستخراج النقاط
void parseAndCheckData(NSData *data) {
    if (!data) return;
    
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (!jsonError && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        
        // التحقق من المسار: data -> pointsData -> points
        NSDictionary *dataDict = dict[@"data"];
        if ([dataDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *pointsData = dataDict[@"pointsData"];
            if ([pointsData isKindOfClass:[NSDictionary class]]) {
                NSNumber *pointsNum = pointsData[@"points"];
                
                if (pointsNum) {
                    NSInteger points = [pointsNum integerValue];
                    
                    // تم التعديل هنا ليكون >= لضمان الحظر حتى لو قفزت النقاط فوق 20
                    if (points >= TARGET_POINTS) {
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
                        
                        // إذا لم يكن هناك حظر سابق أو انتهى الحظر السابق
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

// 1. اعتراض مهام البيانات في NSURLSession (الطبقة الأساسية لاعتراض Alamofire)
%hook NSURLSession

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

%end

// 2. اعتراض تحليل JSON كطبقة احتياطية (في حال تم تحليل البيانات بطريقة مباشرة)
%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    id json = %orig;
    if (json) {
        parseAndCheckData(data);
    }
    return json;
}

%end

// 3. التهيئة ومراقبة حالة التطبيق (عند الفتح أو العودة من الخلفية)
%ctor {
    // فحص حالة الحظر فور فتح التطبيق
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (blockEndTime > now) {
            showBlockOverlay();
        }
    });

    // مراقبة عودة التطبيق من الخلفية (Foreground) لضمان عدم تخطي الحظر
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (blockEndTime > now) {
            showBlockOverlay();
        }
    }];
}
