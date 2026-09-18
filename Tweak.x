#import <Foundation/Foundation.h>
#import <substrate.h>

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *urlString = [url absoluteString];
    
    // فحص ما إذا كان الرابط يخص شركات التتبع
    if ([urlString containsString:@"appsflyer.com"] || 
        [urlString containsString:@"appmetrica.yandex.ru"] || 
        [urlString containsString:@"appmetrica.com"]) {
        
        NSLog(@"[PrivacyTweak] Blocked tracking request to: %@", urlString);
        
        // إرجاع رابط وهمي أو إلغاء الطلب عبر إرجاع مهمة فارغة
        // لكي لا ينهار التطبيق، نقوم بإرجاع بيانات فارغة
        return %orig([NSURL URLWithString:@"about:blank"], completionHandler);
    }
    
    return %orig(url, completionHandler);
}

%end
