#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // الحظر حصرياً عند الوصول إلى 20 نقطة تماماً
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL_PATH @"/api/v1/users/additional/points/data"

// عناصر لوحة التصحيح الموسعة
static UITextView *debugConsoleView = nil;

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

// دالة لإضافة النصوص وسجل الشبكة على الشاشة فوراً
void logToScreen(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (keyWindow) {
            if (!debugConsoleView) {
                // إنشاء نافذة سوداء شفافة بنصف الشاشة العلوي لعرض الطلبات والاستجابات
                debugConsoleView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, keyWindow.bounds.size.width - 20, 220)];
                debugConsoleView.tag = 8888;
                debugConsoleView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.90];
                debugConsoleView.textColor = [UIColor greenColor];
                debugConsoleView.font = [UIFont fontWithName:@"Courier" size:10];
                debugConsoleView.editable = NO;
                debugConsoleView.scrollEnabled = YES;
                debugConsoleView.layer.cornerRadius = 8;
                debugConsoleView.layer.borderWidth = 1.0;
                debugConsoleView.layer.borderColor = [[UIColor greenColor] CGColor];
                
                [keyWindow addSubview:debugConsoleView];
                [keyWindow bringSubviewToFront:debugConsoleView];
            }
            
            // إضافة السجل الجديد مع الحفاظ على القديم
            NSString *currentText = debugConsoleView.text ?: @"";
            NSString *newText = [NSString stringWithFormat:@"%@\n-------------------\n%@", logText, currentText];
            // تحديد الحجم لكي لا يمتلئ النص للأبد
            if (newText.length > 2500) {
                newText = [newText substringToIndex:2500];
            }
            debugConsoleView.text = newText;
        }
    });
}

// دالة عرض شاشة الحظر الإجباري
void showBlockOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (keyWindow && ![keyWindow viewWithTag:9999]) {
            UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
            overlay.tag = 9999;
            overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, keyWindow.bounds.size.width - 40, 40)];
            titleLabel.text = @"توقف مؤقت للتطبيق";
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.font = [UIFont boldSystemFontOfSize:26];
            [overlay addSubview:titleLabel];
            
            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 280, keyWindow.bounds.size.width - 40, 80)];
            descLabel.text = @"لقد وصلت إلى 20 نقطة تماماً.\nسيتوقف التطبيق لمدة 10 دقائق تلقائياً.";
            descLabel.textColor = [UIColor lightGrayColor];
            descLabel.textAlignment = NSTextAlignmentCenter;
            descLabel.numberOfLines = 3;
            descLabel.font = [UIFont systemFontOfSize:16];
            [overlay addSubview:descLabel];
            
            [keyWindow addSubview:overlay];
        }
    });
}

// فحص حالة الحظر فور فتح التطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (blockEndTime > now) {
            logToScreen(@"[!] الحظر ساري مسبقاً بناءً على الذاكرة!");
            showBlockOverlay();
        } else {
            logToScreen(@"[i] التويك يعمل: بانتظار رصد طلبات الشبكة...");
        }
    });
}

// تحليل بيانات الاستجابة وفحص النقاط وطباعة الـ JSON كاملاً على الشاشة
void parseAndCheckData(NSString *urlStr, NSData *data) {
    if (!data) return;
    
    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // إذا كان الرابط يخص النقاط، نعرض تفاصيله بوضوح
    if ([urlStr containsString:TARGET_URL_PATH]) {
        NSString *preview = responseString.length > 300 ? [responseString substringToIndex:300] : responseString;
        logToScreen([NSString stringWithFormat:@"[TARGET URL RESP]:\n%@", preview]);
    }
    
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
                    logToScreen([NSString stringWithFormat:@"[POINTS FOUND]: %ld", (long)points]);
                    
                    if (points == TARGET_POINTS) {
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
                        
                        if (blockEndTime == 0 || blockEndTime <= now) {
                            blockEndTime = now + BLOCK_DURATION;
                            [defaults setDouble:blockEndTime forKey:KEY_BLOCK_END];
                            [defaults synchronize];
                        }
                        
                        logToScreen(@"[!] تم الوصول لـ 20 نقطة! تفعيل الحظر الآن.");
                        showBlockOverlay();
                    }
                }
            }
        }
    }
}

// اعتراض طلبات الشبكة واستخراج الروابط
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = request.URL.absoluteString;
    
    if (urlString) {
        // طباعة الروابط التي تمر لتتبع نشاط التطبيق
        if ([urlString containsString:@"points"] || [urlString containsString:@"user"]) {
            logToScreen([NSString stringWithFormat:@"[REQ]: %@", urlString]);
        }
    }
    
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (urlString) {
            parseAndCheckData(urlString, data);
        }
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(request, wrappedHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL * )url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = url.absoluteString;
    
    if (urlString && ([urlString containsString:@"points"] || [urlString containsString:@"user"])) {
        logToScreen([NSString stringWithFormat:@"[REQ URL]: %@", urlString]);
    }
    
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (urlString) {
            parseAndCheckData(urlString, data);
        }
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(url, wrappedHandler);
}

%end

// اعتراض JSON الشامل
%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    id json = %orig;
    if (json) {
        parseAndCheckData(@"JSON_Serialization", data);
    }
    return json;
}

%end
