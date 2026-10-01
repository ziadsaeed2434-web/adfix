#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // النقاط المستهدفة
#define KEY_BLOCK_END @"block_end_timestamp"

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
        foundWindow = [UIApplication sharedApplication].keyWindow;
    }
    return foundWindow;
}

// 1. دالة تحديث النافذة العائمة للنقاط
void updatePointsWindow(NSInteger points) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;

        // البحث عن النافذة بواسطة الـ tag 8888
        UILabel *pointsLabel = [keyWindow viewWithTag:8888];
        
        if (!pointsLabel) {
            // إنشاء النافذة العائمة إذا لم تكن موجودة
            CGFloat width = 200;
            CGFloat height = 36;
            pointsLabel = [[UILabel alloc] initWithFrame:CGRectMake((keyWindow.bounds.size.width - width)/2, 60, width, height)];
            pointsLabel.tag = 8888;
            pointsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75]; // خلفية سوداء شفافة
            pointsLabel.textColor = [UIColor whiteColor];
            pointsLabel.textAlignment = NSTextAlignmentCenter;
            pointsLabel.font = [UIFont boldSystemFontOfSize:14];
            pointsLabel.layer.cornerRadius = height / 2;
            pointsLabel.layer.masksToBounds = YES;
            pointsLabel.userInteractionEnabled = NO; // لا تعيق اللمس في التطبيق
            [keyWindow addSubview:pointsLabel];
        }
        
        // تحديث النص ورفع النافذة للأعلى
        pointsLabel.text = [NSString stringWithFormat:@"النقاط الحالية: %ld / 20", (long)points];
        [keyWindow bringSubviewToFront:pointsLabel];
    });
}

// 2. دالة عرض شاشة الحظر الكاملة
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (!keyWindow) return;
        
        // منع تكرار الشاشة
        if ([keyWindow viewWithTag:9999]) {
            [keyWindow bringSubviewToFront:[keyWindow viewWithTag:9999]];
            return;
        }
        
        UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
        overlay.tag = 9999;
        overlay.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.98];
        overlay.userInteractionEnabled = YES; // يمنع أي لمسة من الوصول للتطبيق
        
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
void parseAndCheckData(NSDictionary *dict) {
    @try {
        NSDictionary *dataDict = dict[@"data"];
        if (![dataDict isKindOfClass:[NSDictionary class]]) return;
        
        NSDictionary *pointsData = dataDict[@"pointsData"];
        if (![pointsData isKindOfClass:[NSDictionary class]]) return;
        
        NSNumber *pointsNum = pointsData[@"points"];
        if (![pointsNum isKindOfClass:[NSNumber class]]) return;
        
        NSInteger points = [pointsNum integerValue];
        NSLog(@"[Tweak] Current points: %ld", (long)points);
        
        // أولاً: تحديث النافذة العائمة
        updatePointsWindow(points);
        
        // ثانياً: فحص شرط الحظر
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
    } @catch (NSException *exception) {
        NSLog(@"[Tweak] Error parsing JSON: %@", exception.reason);
    }
}

// 4. اعتراض تحليل JSON لالتقاط الاستجابة
%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    id json = %orig;
    
    if (json && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        // فحص سريع للمفاتيح لتجنب تحليل باقي الـ JSON في التطبيق
        if (dict[@"data"] && dict[@"data"][@"pointsData"] && dict[@"data"][@"pointsData"][@"points"]) {
            parseAndCheckData(dict);
        }
    }
    return json;
}

%end

// 5. التهيئة ومراقبة حالة التطبيق
%ctor {
    // فحص حالة الحظر فور فتح التطبيق
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    });

    // مراقبة العودة من الخلفية لضمان عدم تخطي الحظر
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        if (blockEndTime > [[NSDate date] timeIntervalSince1970]) {
            showBlockOverlay();
        }
    }];
}
