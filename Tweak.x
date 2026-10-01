#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITextView *universalLogView = nil;
static NSMutableDictionary *flexActiveTransactions = nil;

void showUniversalLog(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
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
            UIView *overlay = [keyWindow viewWithTag:999888];
            if (!overlay) {
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 30, keyWindow.bounds.size.width - 20, 390)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.98];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:7.5];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] FLEX-Engine Network Monitor Active...\n";
                
                [overlay addSubview:universalLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (!flexActiveTransactions) {
                flexActiveTransactions = [NSMutableDictionary dictionary];
            }
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// هيكل لتخزين معلومات الطلب على طريقة FLEXNetworkTransaction
@interface FlexTransactionInfo : NSObject
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSDate *startDate;
@end

@implementation FlexTransactionInfo
@end

// تطبيق مبدأ Swizzling على NSURLSessionTask وطبقات الـ Delegates تماماً مثل FLEX
@implementation NSObject (FlexNetworkInspector)

// اعتراض إنشاء مهام البيانات في NSURLSession
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // يمكن تنفيذ Swizzling المتقدم هنا لدوال الـ Session Delegates
    });
}

@end

// ==========================================
// مراقبة شاملة لجميع مهام NSURLSession والدالة الأم للاستجابات
// ==========================================
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSURLSessionDataTask *task = %orig;
    if (task) {
        NSString *url = [request.URL absoluteString] ?: @"<Unknown>";
        NSString *method = request.HTTPMethod ?: @"GET";
        
        // استخراج Headers تماماً مثل فليكس
        NSDictionary *headers = request.allHTTPHeaderFields;
        NSMutableString *hdrStr = [NSMutableString string];
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            [hdrStr appendFormat:@"  %@: %@\n", k, v];
        }];
        
        NSString *log = [NSString stringWithFormat:@"[FLEX Request]\nURL: %@\nMethod: %@\nMechanism: NSURLSessionDataTask\n[Headers]:\n%@", 
                         url, method, hdrStr.length > 0 ? hdrStr : @"  <None>\n"];
        showUniversalLog(log);
    }
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    NSURLSessionUploadTask *task = %orig;
    if (task) {
        NSString *url = [request.URL absoluteString] ?: @"<Unknown>";
        NSString *method = request.HTTPMethod ?: @"POST";
        NSString *log = [NSString stringWithFormat:@"[FLEX Upload]\nURL: %@\nMethod: %@", url, method];
        showUniversalLog(log);
    }
    return task;
}

%end

// ==========================================
// التقاط الردود الفعلية عبر تفويض النظام (didReceiveData و didReceiveResponse)
// وهو السر الذي تعتمد عليه FLEX لاصطياد استجابات Alamofire والتطبيق
// ==========================================
%hook NSObject

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    %orig;
    if (dataTask) {
        NSValue *key = [NSValue valueWithNonretainedObject:dataTask];
        if (!flexActiveTransactions) flexActiveTransactions = [NSMutableDictionary dictionary];
        
        FlexTransactionInfo *info = [[FlexTransactionInfo alloc] init];
        info.request = dataTask.currentRequest ?: dataTask.originalRequest;
        info.response = response;
        info.data = [NSMutableData data];
        info.startDate = [NSDate date];
        flexActiveTransactions[key] = info;
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    %orig;
    if (dataTask && data) {
        NSValue *key = [NSValue valueWithNonretainedObject:dataTask];
        FlexTransactionInfo *info = flexActiveTransactions[key];
        if (info) {
            [info.data appendData:data];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    %orig;
    if (task) {
        NSValue *key = [NSValue valueWithNonretainedObject:task];
        FlexTransactionInfo *info = flexActiveTransactions[key];
        if (info) {
            NSString *url = [info.request.URL absoluteString] ?: @"<Unknown>";
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)info.response;
            NSInteger status = [httpResp statusCode];
            
            NSString *respBody = @"<No Data>";
            if (info.data.length > 0) {
                respBody = [[NSString alloc] initWithData:info.data encoding:NSUTF8StringEncoding];
                if (!respBody) respBody = [NSString stringWithFormat:@"<Binary Size: %lu bytes>", (unsigned long)info.data.length];
                if (respBody.length > 350) respBody = [respBody substringToIndex:350];
            } else if (error) {
                respBody = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
            }
            
            // تنسيق مخصص يطابق تماماً تقارير أداة فليكس
            NSString *log = [NSString stringWithFormat:@"[FLEX Complete]\nURL: %@\nStatus: %ld\nMechanism: NSURLSession (Delegate)\n[Response Body]:\n%@", 
                             url, (long)status, respBody];
            showUniversalLog(log);
            
            [flexActiveTransactions removeObjectForKey:key];
        }
    }
}

%end
