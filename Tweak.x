#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static dispatch_queue_t getDelayQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.delayQueue", DISPATCH_QUEUE_SERIAL);
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
    
    // فحص الطلب الخاص بالمكافآت
    if (urlString && [urlString containsString:@"/api/v1/users/additional/"]) {
        
        // توليد وقت تأخير عشوائي وآمن من دقيقة إلى دقيقتين (60 إلى 120 ثانية)
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        
        // تأخير تنفيذ الطلب الأصلي نفسه في الخلفية
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getDelayQueue(), ^{
            // استدعاء %orig الحقيقية لتنفيذ الطلب الأصلي بعد انتهاء الوقت المحدد
            %orig;
        });
        
        return; // منع التشغيل الفوري وإبقاء الطلب معلقاً للمدة المحددة
    }
    
    %orig;
}

%end
