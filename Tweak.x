#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // الحظر عند الوصول إلى 20 نقطة تماماً
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL @"https://tn.maildisposable.com/api/v1/users/additional/points/data"

// دالة عرض شاشة الحظر الإجباري المانعة للتفاعل
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow && ![keyWindow viewWithTag:9999]) {
            UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
            overlay.tag = 9999;
            overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, keyWindow.bounds.size.width - 40, 40)];
            titleLabel.text = @"توقف مؤقت للتطبيق";
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.font = [UIFont boldSystemFontOfSize:26]; // تم التصحيح هنا إلى UIFont
            [overlay addSubview:titleLabel];
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 280, keyWindow.bounds.size.width - 40, 80)];
            descLabel.text = @"لقد وصلت إلى 20 نقطة تماماً.\nسيتوقف التطبيق لمدة 10 دقائق تلقائياً.";
            descLabel.textColor = [UIColor lightGrayColor];
            descLabel.textAlignment = NSTextAlignmentCenter;
            descLabel.numberOfLines = 3;
            descLabel.font = [UIFont systemFontOfSize:16]; // وتم التصحيح هنا إلى UIFont
            [overlay addSubview:descLabel];
            
            [keyWindow addSubview:overlay];
        }
    });
}

// فحص حالة الحظر فور فتح التطبيق لضمان استمرار الـ 10 دقائق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (blockEndTime > now) {
            showBlockOverlay();
        }
    });
}

// دالة مركزية للتحقق من قيمة النقاط وتطبيق الحظر فوراً عندما تصل إلى 20 حصراً
void processPointsCheck(id jsonObject) {
    if ([jsonObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)jsonObject;
        
        // التحقق من المسار الدقيق للاستجابة: data -> pointsData -> points
        NSDictionary *dataDict = dict[@"data"];
        if ([dataDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *pointsData = dataDict[@"pointsData"];
            if ([pointsData isKindOfClass:[NSDictionary class]]) {
                NSNumber *pointsNum = pointsData[@"points"];
                
                if (pointsNum) {
                    NSInteger points = [pointsNum integerValue];
                    
                    // الشرط الحصري: عندما تكون القيمة 20 تماماً
                    if (points == TARGET_POINTS) {
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

// --- الطبقة الأولى: اعتراض فك شفرة الـ JSON (شاملة ومضمونة) ---
%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    id json = %orig;
    if (json) {
        processPointsCheck(json);
    }
    return json;
}

%end

// --- الطبقة الثانية: اعتراض طلبات الشبكة للرابط الكامل والمحدد بحذافيره ---
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = request.URL.absoluteString;
    
    // مطابقة الرابط كاملاً وحرفياً كما طلبته
    if (urlString && [urlString isEqualToString:TARGET_URL]) {
        void (^safeHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (data) {
                NSError *jsonError = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (!jsonError && json) {
                    processPointsCheck(json);
                }
            }
            if (completionHandler) {
                completionHandler(data, response, error);
            }
        };
        return %orig(request, safeHandler);
    }
    
    return %orig(request, completionHandler);
}

%end
