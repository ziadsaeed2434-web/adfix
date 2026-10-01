#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // النقاط المستهدفة
#define KEY_BLOCK_END @"block_end_timestamp"

static NSMutableDictionary *taskDataDict = nil;

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

// دالة البحث التلقائي عن النقاط في أي مكان داخل الـ JSON
NSInteger findPointsInJSON(id json) {
    if ([json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        id pointsObj = dict[@"points"];
        if (pointsObj) {
            if ([pointsObj isKindOfClass:[NSNumber class]]) return [pointsObj integerValue];
            if ([pointsObj isKindOfClass:[NSString class]]) return [pointsObj integerValue];
        }
        for (id key in dict) {
            NSInteger result = findPointsInJSON(dict[key]);
            if (result != -1) return result;
        }
    } else if ([json isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)json;
        for (id item in arr) {
            NSInteger result = findPointsInJSON(item);
            if (result != -1) return result;
        }
    }
    return -1; // لم يتم العثور على النقاط
}

// 1. دالة تحديث النافذة العائمة
void updatePointsWindow(NSInteger points) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;

        UILabel *pointsLabel = [keyWindow viewWithTag:8888];
        if (!pointsLabel) {
            CGFloat width = 220;
            CGFloat height = 40;
            pointsLabel = [[UILabel alloc] initWithFrame:CGRectMake((keyWindow.bounds.size.width - width)/2, 60, width, height)];
            pointsLabel.tag = 8888;
            pointsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
            pointsLabel.textColor = [UIColor whiteColor];
            pointsLabel.textAlignment = NSTextAlignmentCenter;
            pointsLabel.font = [UIFont boldSystemFontOfSize:15];
            pointsLabel.layer.cornerRadius = height / 2;
            pointsLabel.layer.masksToBounds = YES;
            pointsLabel.userInteractionEnabled = NO;
            [keyWindow addSubview:pointsLabel];
        }
        
        pointsLabel.text = [NSString stringWithFormat:@"النقاط الحالية: %ld / 20", (long)points];
        [keyWindow bringSubviewToFront:pointsLabel];
    });
}

// 2. دالة عرض شاشة الحظر
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow || [keyWindow viewWithTag:9999]) return;
        
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

// 3. دالة تحليل البيانات
void parseAndCheckData(NSData *data) {
    if (!data) return;
    @try {
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (!jsonError && json) {
            NSInteger points = findPointsInJSON(json);
            if (points != -1) {
                NSLog(@"[Tweak] Found points: %ld", (long)points);
                updatePointsWindow(points);
                
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
    } @catch (NSException *exception) {
        NSLog(@"[Tweak] Error parsing JSON: %@", exception.reason);
    }
}

// 4. اعتراض الشبكة (يغطي جميع الطرق)
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        parseAndCheckData(data);
        if (completionHandler) completionHandler(data, response, error);
    };
    return %orig(request, wrappedHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        parseAndCheckData(data);
        if (completionHandler) completionHandler(data, response, error);
    };
    return %orig(url, wrappedHandler);
}
%end

// اعتراض الـ Delegate الخاص بـ Alamofire (لأنه يستخدم هذه الطريقة)
%hook NSObject
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    %orig;
    if (!taskDataDict) taskDataDict = [NSMutableDictionary dictionary];
    NSMutableData *accumulatedData = taskDataDict[@(dataTask.taskIdentifier)];
    if (!accumulatedData) {
        accumulatedData = [NSMutableData data];
        taskDataDict[@(dataTask.taskIdentifier)] = accumulatedData;
    }
    [accumulatedData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    %orig;
    if (taskDataDict) {
        NSMutableData *accumulatedData = taskDataDict[@(task.taskIdentifier)];
        if (accumulatedData) {
            parseAndCheckData(accumulatedData);
            [taskDataDict removeObjectForKey:@(task.taskIdentifier)];
        }
    }
}
%end

// 5. التهيئة
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // إنشاء النافذة العائمة فوراً
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (keyWindow && ![keyWindow viewWithTag:8888]) {
            UILabel *pointsLabel = [[UILabel alloc] initWithFrame:CGRectMake((keyWindow.bounds.size.width - 220)/2, 60, 220, 40)];
            pointsLabel.tag = 8888;
            pointsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
            pointsLabel.textColor = [UIColor whiteColor];
            pointsLabel.textAlignment = NSTextAlignmentCenter;
            pointsLabel.font = [UIFont boldSystemFontOfSize:15];
            pointsLabel.layer.cornerRadius = 20;
            pointsLabel.layer.masksToBounds = YES;
            pointsLabel.userInteractionEnabled = NO;
            pointsLabel.text = @"النقاط الحالية: جاري التحديث...";
            [keyWindow addSubview:pointsLabel];
        }
        
        // فحص حالة الحظر
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    }];
}
