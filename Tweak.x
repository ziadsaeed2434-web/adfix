#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static dispatch_queue_t getTrueDelayQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.trueDelayQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

%hook NSURLSessionTask

- (void)resume {
    NSURLRequest *request = self.currentRequest;
    if (!request) {
        request = [self valueForKey:@"originalRequest"];
    }
    
    NSString *urlString = [[request URL] absoluteString];
    
    if (urlString && [urlString containsString:@"/api/v1/users/additional/"]) {
        
        // 1. توليد وقت تأخير عشوائي حقيقي من دقيقة إلى دقيقتين (60 إلى 120 ثانية)
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        
        NSURLRequest *savedRequest = [request copy];
        
        // 2. تأخير إرسال الطلب الأصلي نفسه للسيرفر للمدة المطلوبة
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getTrueDelayQueue(), ^{
            // هنا يتم إرسال الطلب الأصلي فعلياً بعد انتهاء الدقيقة أو الدقيقتين
            [[[NSURLSession sharedSession] dataTaskWithRequest:savedRequest] resume];
        });
        
        // 3. منع الإرسال الفوري للطلب الأصلي حتى ينتظر المدة المحددة
        return;
    }
    
    %orig;
}

%end
