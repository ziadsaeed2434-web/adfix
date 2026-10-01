#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // النقاط المستهدفة
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL_PATH @"api/v1/users/additional/points/data"

// قاموس لتخزين بيانات المهام مؤقتاً
static NSMutableDictionary *taskDataDict = nil;

// دالة آمنة لجلب النافذة النشطة
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
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                foundWindow = window;
                break;
            }
        }
    }
    return foundWindow;
}

// 1. دالة إنشاء وتحديث النافذة العائمة (تظهر دائماً)
void setupPointsWindow() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;

        UILabel *pointsLabel = [keyWindow viewWithTag:8888];
        if (!pointsLabel) {
            CGFloat width = 220;
            CGFloat height = 40;
            // تظهر في أعلى منتصف الشاشة
            pointsLabel = [[UILabel alloc] initWithFrame:CGRectMake((keyWindow.bounds.size.width - width)/2, 60, width, height)];
            pointsLabel.tag = 8888;
            pointsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
            pointsLabel.textColor = [UIColor whiteColor];
            pointsLabel.textAlignment = NSTextAlignmentCenter;
            pointsLabel.font = [UIFont boldSystemFontOfSize:15];
            pointsLabel.layer.cornerRadius = height / 2;
            pointsLabel.layer.masksToBounds = YES;
            pointsLabel.userInteractionEnabled = NO; // لا تعيق اللمس في التطبيق
            pointsLabel.text = @"النقاط الحالية: جاري التحديث...";
            [keyWindow addSubview:pointsLabel];
        }
        [keyWindow bringSubviewToFront:pointsLabel];
    });
}

// دالة تحديث نص النافذة العائمة
void updatePointsWindow(NSInteger points) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        UILabel *pointsLabel = [keyWindow viewWithTag:8888];
        if (pointsLabel) {
            pointsLabel.text = [NSString stringWithFormat:@"النقاط الحالية: %ld / 20", (long)points];
            [keyWindow bringSubviewToFront:pointsLabel];
        }
    });
}

// 2. دالة عرض شاشة الحظر الكاملة
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;
        
        if ([keyWindow viewWithTag:9999]) {
            [keyWindow bringSubviewToFront:[keyWindow viewWithTag:9999]];
            return;
        }
        
        UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
        overlay.tag = 9999;
        overlay.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.98];
        overlay.userInteractionEnabled = YES;
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, keyWindow.bounds.size.width - 40, 40)];
        titleLabel.text = @"⛔️ توقف مؤقت للتطبيق";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:26];
        [overlay addSubview:titleLabel];
        
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 280, keyWindow.bounds.size.width - 40, 80)];
        descLabel.text = @"لقد وصلت إلى 20 نقطة.\nسيتوقف التطبيق عن العمل لمدة 10 دقائق.";
        descLabel.textColor = [UIColor lightGrayColor];
        descLabel.textAlignment = NSTextAlignmentCenter;
        descLabel.numberOfLines = 3;
        descLabel.font = [UIFont systemFontOfSize:16];
        [overlay addSubview:descLabel];
        
        [keyWindow addSubview:overlay];
        [keyWindow bringSubviewToFront:overlay];
    });
}

// 3. دالة تحليل البيانات وفحص النقاط
void parseAndCheckData(NSData *data) {
    if (!data) return;
    
    @try {
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (!jsonError && [json isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)json;
            NSDictionary *dataDict = dict[@"data"];
            
            if ([dataDict isKindOfClass:[NSDictionary class]]) {
                NSDictionary *pointsData = dataDict[@"pointsData"];
                if ([pointsData isKindOfClass:[NSDictionary class]]) {
                    NSNumber *pointsNum = pointsData[@"points"];
                    
                    if ([pointsNum isKindOfClass:[NSNumber class]]) {
                        NSInteger points = [pointsNum integerValue];
                        NSLog(@"[Tweak] Current points: %ld", (long)points);
                        
                        // تحديث النافذة العائمة
                        updatePointsWindow(points);
                        
                        // فحص شرط الحظر
                        if (points >= TARGET_POINTS) {
                            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                            NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
                            
                            if (blockEndTime == 0 || blockEndTime <= now) {
                                blockEndTime = now + BLOCK_DURATION;
                                [defaults setDouble:blockEndTime forKey:KEY_BLOCK_END];
                                [defaults synchronize];
                                NSLog(@"[Tweak] Blocking app for 10 minutes!");
                            }
                            
                            showBlockOverlay();
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[Tweak] Error parsing JSON: %@", exception.reason);
    }
}

// 4. اعتراض الشبكة مباشرة (الطريقة المضمونة مع Alamofire)
%hook NSObject

// التقاط البيانات الخام أثناء وصولها
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    %orig;
    NSString *urlString = dataTask.currentRequest.URL.absoluteString ?: dataTask.originalRequest.URL.absoluteString;
    if (urlString && [urlString containsString:TARGET_URL_PATH]) {
        if (!taskDataDict) taskDataDict = [NSMutableDictionary dictionary];
        NSMutableData *accumulatedData = taskDataDict[@(dataTask.taskIdentifier)];
        if (!accumulatedData) {
            accumulatedData = [NSMutableData data];
            taskDataDict[@(dataTask.taskIdentifier)] = accumulatedData;
        }
        [accumulatedData appendData:data];
    }
}

// عند اكتمال المهمة، نقوم بتحليل البيانات المجمعة
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    %orig;
    NSString *urlString = task.currentRequest.URL.absoluteString ?: task.originalRequest.URL.absoluteString;
    if (urlString && [urlString containsString:TARGET_URL_PATH]) {
        if (taskDataDict) {
            NSMutableData *accumulatedData = taskDataDict[@(task.taskIdentifier)];
            if (accumulatedData) {
                parseAndCheckData(accumulatedData);
                [taskDataDict removeObjectForKey:@(task.taskIdentifier)];
            }
        }
    }
}

%end

// 5. التهيئة ومراقبة حالة التطبيق
%ctor {
    // 1. إنشاء النافذة العائمة فوراً عند فتح التطبيق
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        setupPointsWindow(); // تظهر النافذة دائماً
        
        // فحص حالة الحظر عند العودة
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    }];
    
    // 2. فحص أولي عند الإقلاع (تأخير بسيط لضمان اكتمال تحميل الواجهة)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupPointsWindow();
    });
}
