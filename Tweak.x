#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static UITextView *universalLogView = nil;

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
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 35, keyWindow.bounds.size.width - 20, 300)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.94];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:8.5];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] Full Request/Response Monitor Active...\n";
                
                [overlay addSubview:universalLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// دالة لمعالجة الطلب والاستجابة معاً (بما في ذلك بيانات الـ POST المرسلة)
static void handleRequestAndResponse(NSURLRequest *request, NSData *responseData, NSURLResponse *response, NSError *error) {
    NSString *urlString = [request.URL absoluteString];
    if (!urlString) {
        urlString = [response.URL absoluteString];
    }
    if (!urlString) {
        urlString = @"<Unknown URL>";
    }
    
    NSString *method = request.HTTPMethod ? request.HTTPMethod : @"GET";
    
    // استخراج البيانات المرسلة في الـ POST (إن وجدت)
    NSString *requestBodyString = @"";
    NSData *bodyData = request.HTTPBody;
    if (bodyData) {
        requestBodyString = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        if (!requestBodyString) {
            requestBodyString = [NSString stringWithFormat:@"<Binary Data Size: %lu>", (unsigned long)bodyData.length];
        } else if (requestBodyString.length > 200) {
            requestBodyString = [requestBodyString substringToIndex:200];
        }
    }
    
    // استخراج بيانات الاستجابة (Response)
    NSString *responseString = @"";
    if (responseData) {
        responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if (!responseString) {
            responseString = [NSString stringWithFormat:@"<Binary Data Size: %lu>", (unsigned long)responseData.length];
        } else if (responseString.length > 300) {
            responseString = [responseString substringToIndex:300];
        }
    } else if (error) {
        responseString = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpResponse statusCode];
    
    // بناء النص المعروض في النافذة
    NSString *log = [NSString stringWithFormat:@"[%@] Status: %ld\nURL: %@\nReqBody: %@\nResBody: %@", 
                     method, (long)statusCode, urlString, 
                     requestBodyString.length > 0 ? requestBodyString : @"<None>", 
                     responseString.length > 0 ? responseString : @"<No Data>"];
    
    showUniversalLog(log);
}

%hook NSURLSession

// 1. التقاط طلبات الـ URL المباشر (GET العادية)
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleRequestAndResponse(request, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(url, wrappedHandler);
}

// 2. التقاط جميع طلبات الـ NSURLRequest (تشمل GET, POST, PUT وغيرها بكل تفاصيلها)
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleRequestAndResponse(request, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(request, wrappedHandler);
}

// 3. التقاط مهام الرفع أو إرسال البيانات الكبيرة (Upload Tasks)
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    // دمج البيانات المرسلة لو لم تكن موجودة في الـ request الأصلي
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (bodyData && !mutableReq.HTTPBody) {
        mutableReq.HTTPBody = bodyData;
    }
    
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleRequestAndResponse(mutableReq, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(request, bodyData, wrappedHandler);
}

%end
