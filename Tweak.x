#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// إنشاء طابور خلفي آمن لتنفيذ الطلبات بشكل تسلسلي وببطء
static dispatch_queue_t getSafeQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.safeQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    NSString *urlString = [[request URL] absoluteString];
    
    // استهداف مسارات المكافآت والنقاط المرتبطة بالحظر بناءً على السجلات التي أرسلتها
    if ([urlString containsString:@"/api/v1/users/additional/shake"] || [urlString containsString:@"/api/v1/users/additional/points"]) {
        
        // توليد فترة انتظار عشوائية وآمنة بين 60 إلى 120 ثانية (دقيقة إلى دقيقتين)
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        
        NSURLRequest *savedRequest = [request copy];
        
        // إرسال الطلب الفعلي للسيرفر في الخلفية بعد انقضاء الوقت العشوائي الآمن
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getSafeQueue(), ^{
            NSURLSessionDataTask *backgroundTask = [[NSURLSession sharedSession] dataTaskWithRequest:savedRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // تنفيذ صامت للطلب في الخلفية
            }];
            [backgroundTask resume];
        });
        
        // منح استجابة نجاح فورية للواجهة لكي تظهر النقاط لديك مباشرة دون أي انتظار
        if (completionHandler) {
            NSData *fakeData = [@"{\"success\":true,\"status\":\"ok\"}" dataUsingEncoding:NSUTF8StringEncoding];
            NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}] ;
            completionHandler(fakeData, fakeResponse, nil);
        }
        
        return %orig(request, nil);
    }
    
    return %orig(request, completionHandler);
}

%end
