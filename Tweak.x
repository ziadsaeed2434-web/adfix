#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// طابور خلفي آمن وموحد لإدارة وتأخير الطلبات
static dispatch_queue_t getMasterQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.masterQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

// دالة موحدة لتأخير الطلب وإرساله صامتاً في الخلفية بعد وقت عشوائي آمن (60 إلى 120 ثانية)
static void delayAndSendRequest(NSURLRequest *originalRequest) {
    u_int32_t randomDelay = 60 + arc4random_uniform(61);
    NSURLRequest *savedRequest = [originalRequest copy];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getMasterQueue(), ^{
        NSURLSessionDataTask *bgTask = [[NSURLSession sharedSession] dataTaskWithRequest:savedRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // إرسال صامت في الخلفية
        }];
        [bgTask resume];
    });
}

// --- الطبقة الأولى: اعتراض NSURLSession القياسية ---
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSString *urlString = [[request URL] absoluteString];
    
    if ([urlString containsString:@"/api/v1/users/additional/"]) {
        delayAndSendRequest(request);
        
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

// --- الطبقة الثانية: اعتراض NSURLRequest عند توليد الروابط ---
%hook NSURLRequest

+قات (اختياري للإضافة) - (id)requestWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval {
    NSString *urlString = https://developer.apple.com/documentation/foundation/nsurl/absolutestring;
    if ([urlString containsString:@"/api/v1/users/additional/"]) {
        NSURLRequest *origReq = %orig;
        delayAndSendRequest(origReq);
    }
    return %orig;
}

%end

// --- الطبقة الثالثة: اعتراض الـ NSURL من الجذور لضمان عدم هروب أي طلب ---
%hook NSURL

- (instancetype)initWithString:(NSString *)URLString {
    if ([URLString containsString:@"/api/v1/users/additional/"]) {
        // التقاط وتأخير من الجذور
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)), getMasterQueue(), ^{
            NSURL *url = [NSURL URLWithString:URLString];
            NSURLRequest *req = [NSURLRequest requestWithURL:url];
            [[[NSURLSession sharedSession] dataTaskWithRequest:req] resume];
        });
    }
    return %orig;
}

%end
