#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static dispatch_queue_t getStrictQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.tweak.strictQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

%hook NSURLSessionTask

// اعتراض عملية "بدء أو إرسال" أي طلب شبكة في النظام لحظة تنفيذه
- (void)resume {
    NSURLRequest *request = self.currentRequest;
    if (!request) {
        request = [self valueForKey:@"originalRequest"];
    }
    
    NSString *urlString = [[request URL] absoluteString];
    
    if (urlString && [urlString containsString:@"/api/v1/users/additional/"]) {
        
        // إلغاء الإرسال الفوري للسيرفر لمنع ظهوره في أداة الفحص والتسبب بالحظر
        %orig; // أو يمكننا عمل cancel لمنع الطلب الأصلي تماماً وإعادة توجيهه
        [self cancel];
        
        // توليد وقت التأخير العشوائي في الخلفية (بين دقيقة إلى دقيقتين)
        u_int32_t randomDelay = 60 + arc4random_uniform(61);
        NSURLRequest *savedRequest = [request copy];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomDelay * NSEC_PER_SEC)), getStrictQueue(), ^{
            NSURLSessionDataTask *delayedTask = [[NSURLSession sharedSession] dataTaskWithRequest:savedRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // إرسال الطلب بشكل صامت ومتأخر في الخلفية
            }];
            [delayedTask resume];
        });
        
        return;
    }
    
    %orig;
}

%end
