#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// طابور خلفي لضمان تسلسل الطلبات وإرسالها ببطء وأمان تام
static dispatch_queue_t getSafeQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.safe.requestQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    NSString *urlString = [[request URL] absoluteString];
    
    // استهداف مسارات النقاط والمكافآت والمهام التي تؤدي للحظر بناءً على فحص الـ API لديك
    if ([urlString containsString:@"/api/v1/users/additional/"] || [urlString containsString:@"points"] || [urlString containsString:@"shake"]) {
        
        // توليد وقت تأخير عشوائي آمن في الخلفية يتراوح بين 60 إلى 120 ثانية (دقيقة إلى دقيقتين)
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        
        NSURLRequest *savedRequest = [request copy];
        
        // تأخير تنفيذ وإرسال الطلب الفعلي للسيرفر في الخلفية
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getSafeQueue(), ^{
            // يتم إرسال الطلب الحقيقي للسيرفر بهدوء وبفواصل زمنية بشرية
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:savedRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // يمكن معالجة الرد صامتاً في الخلفية
            }];
            [task resume];
        });
        
        // إعطاء استجابة نجاح وهمية وفورية للواجهة لكي يظهر لك التطبيق أن النقاط أُضيفَت فوراً ودون أي انتظار
        if (completionHandler) {
            NSData *fakeData = [@"{\"success\":true,\"status\":\"ok\"}" dataUsingEncoding:NSUTF8StringEncoding];
            NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}] ;
            completionHandler(fakeData, fakeResponse, nil);
        }
        
        // إرجاع مهمل أو مهمة فارغة لمنع التداخل البصري بينما يتم التعامل مع الطلب في الخلفية
        return %orig(request, nil);
    }
    
    return %orig(request, completionHandler);
}

%end
