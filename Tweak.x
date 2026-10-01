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
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 35, keyWindow.bounds.size.width - 20, 350)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.96];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:8];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] Full Response Monitor Active...\n";
                
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

// دالة لمعالجة الطلب واستخراج الـ Response Body وعرضه بالتفصيل
static void handleTaskCompletion(NSURLRequest *request, NSData *data, NSURLResponse *response, NSError *error) {
    NSString *urlString = [request.URL absoluteString];
    if (!urlString) urlString = [response.URL absoluteString];
    if (!urlString) urlString = @"<Unknown URL>";
    
    NSString *method = request.HTTPMethod ? request.HTTPMethod : @"GET";
    
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpResp statusCode];
    
    // استخراج الـ Headers
    NSDictionary *headers = request.allHTTPHeaderFields;
    NSMutableString *headersStr = [NSMutableString string];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [headersStr appendFormat:@"  %@: %@\n", key, obj];
    }];
    
    // استخراج بيانات الطلب المرسل (Request Body)
    NSData *reqBodyData = request.HTTPBody;
    NSString *reqBodyStr = @"<None>";
    if (reqBodyData) {
        reqBodyStr = [[NSString alloc] initWithData:reqBodyData encoding:NSUTF8StringEncoding];
        if (!reqBodyStr) reqBodyStr = [NSString stringWithFormat:@"<Binary Size: %lu>", (unsigned long)reqBodyData.length];
    }
    
    // ** استخراج محتوى الاستجابة (Response Body) وهو الأهم **
    NSString *respBodyStr = @"<No Response Data>";
    if (data) {
        respBodyStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!respBodyStr) {
            respBodyStr = [NSString stringWithFormat:@"<Binary Data Size: %lu bytes>", (unsigned long)data.length];
        }
    } else if (error) {
        respBodyStr = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    }
    
    // بناء الشكل النهائي للتقرير داخل النافذة
    NSString *log = [NSString stringWithFormat:@"[%@] URL: %@\nStatus: %ld\n[Headers]:\n%@[ReqBody]: %@\n[Response Body]:\n%@", 
                     method, 
                     urlString, 
                     (long)statusCode, 
                     headersStr.length > 0 ? headersStr : @"  <None>\n", 
                     reqBodyStr, 
                     respBodyStr];
    
    showUniversalLog(log);
}

%hook NSURLSession

// 1. اعتراض طلبات الـ Data مع الـ Completion Handler لضمان جلب الـ Response
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleTaskCompletion(request, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(request, wrappedHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL * )url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleTaskCompletion(request, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(url, wrappedHandler);
}

// 2. اعتراض طلبات الـ Upload (مثل POST الحساسة الخاصة بالنقاط) وجلب استجابتها
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (bodyData && !mutableReq.HTTPBody) {
        mutableReq.HTTPBody = bodyData;
    }
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        handleTaskCompletion(mutableReq, data, response, error);
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    return %orig(request, bodyData, wrappedHandler);
}

%end
