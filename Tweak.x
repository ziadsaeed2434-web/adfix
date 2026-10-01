#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>

#define BLOCK_DURATION 600.0 // 10 دقائق بالثواني
#define TARGET_POINTS 20     // الحظر حصرياً عند الوصول إلى 20 نقطة تماماً
#define KEY_BLOCK_END @"block_end_timestamp"
#define TARGET_URL_PATH @"/api/v1/users/additional/points/data"

static UITextView *debugConsoleView = nil;

// دالة آمنة جداً لجلب النافذة النشطة لمنع الـ Crash
UIWindow *getSafelyKeyWindow() {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
    }
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    return window;
}

// دالة طباعة السجلات على الشاشة بشكل آمن
void logToScreen(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafelyKeyWindow();
        if (keyWindow) {
            if (!debugConsoleView) {
                debugConsoleView = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 20, 200)];
                debugConsoleView.tag = 8888;
                debugConsoleView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.85];
                debugConsoleView.textColor = [UIColor greenColor];
                debugConsoleView.font = [UIFont systemFontOfSize:9];
                debugConsoleView.editable = NO;
                debugConsoleView.scrollEnabled = YES;
                debugConsoleView.layer.cornerRadius = 6;
                debugConsoleView.layer.borderWidth = 1.0;
                debugConsoleView.layer.borderColor = [[UIColor greenColor] CGColor];
                
                [keyWindow addSubview:debugConsoleView];
                [keyWindow bringSubviewToFront:debugConsoleView];
            }
            
            NSString *currentText = debugConsoleView.text ?: @"";
            NSString *newText = [NSString stringWithFormat:@"%@\n---\n%@", logText, currentText];
            if (newText.length > 2000) {
                newText = [newText substringToIndex:2000];
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

// فحص حالة الحظر بعد تأخير آمن لضمان اكتمال فتح التطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (blockEndTime > now) {
            logToScreen(@"[!] الحظر ساري مسبقاً!");
            showBlockOverlay();
        } else {
            logToScreen(@"[i] التويك يعمل بنجاح، بانتظار الطلبات...");
        }
    });
}

// تحليل بيانات الاستجابة وفحص النقاط
void parseAndCheckData(NSString *urlStr, NSData *data) {
    if (!data) return;
    
    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([urlStr containsString:TARGET_URL_PATH]) {
        NSString *preview = responseString.length > 200 ? [responseString substringToIndex:200] : responseString;
        logToScreen([NSString stringWithFormat:@"[RESP]: %@", preview]);
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
                    logToScreen([NSString stringWithFormat:@"[POINTS]: %ld", (long)points]);
                    
                    if (points == TARGET_POINTS) {
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                        NSTimeInterval blockEndTime = [defaults doubleForKey:KEY_BLOCK_END];
                        
                        if (blockEndTime == 0 || blockEndTime <= now) {
                            blockEndTime = now + BLOCK_DURATION;
                            [defaults setDouble:blockEndTime forKey:KEY_BLOCK_END];
                            [defaults synchronize];
                        }
                        
                        logToScreen(@"[!] وصلت 20 نقطة! تفعيل الحظر.");
                        showBlockOverlay();
                    }
                }
            }
        }
    }
}

// اعتراض طلبات الشبكة بأمان
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = request.URL.absoluteString;
    if (urlString && ([urlString containsString:@"points"] || [urlString containsString:@"user"])) {
        logToScreen([NSString stringWithFormat:@"[REQ]: %@", urlString]);
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

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
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
        parseAndCheckData(@"JSON", data);
    }
    return json;
}

%end
