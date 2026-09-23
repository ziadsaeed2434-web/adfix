#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static dispatch_queue_t getUltimateQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.ultimateQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSString *urlString = [[request URL] absoluteString];
    
    if (urlString && [urlString containsString:@"/api/v1/users/additional/"]) {
        
        // 1. إعطاء استجابة نجاح وهمية وفورية للواجهة لكي تظهر النقاط فوراً ولا يحدث أي تعليق أو أخطاء
        if (completionHandler) {
            NSData *fakeData = [@"{\"success\":true,\"status\":\"ok\",\"points\":1}" dataUsingEncoding: NSUTF8StringEncoding];
            NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}] ;
            completionHandler(fakeData, fakeResponse, nil);
        }
        
        // 2. أخذ الطلب الحقيقي وتأخير إرساله الفعلي للسيرفر في الخلفية (من دقيقة إلى دقيقتين) للحماية من الحظر
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        NSURLRequest *savedRequest = [request copy];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getUltimateQueue(), ^{
            NSURLSessionDataTask *bgTask = [[NSURLSession sharedSession] dataTaskWithRequest:savedRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // إرسال الطلب الحقيقي صامتاً في الخلفية بعد انتهاء الوقت
            }];
            [bgTask resume];
        });
        
        return %orig(request, nil);
    }
    
    return %orig(request, completionHandler);
}

%end
