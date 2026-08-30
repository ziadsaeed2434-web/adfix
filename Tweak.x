#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// هوك لطلبات الشبكة وتعديل الهيدرز أو الـ User-Agent لإجبار السيرفر على الاستجابة
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    // التحقق مما إذا كان الطلب موجهاً لشبكات الإعلانات أو الـ Mediation
    NSString *urlString = [[request URL] absoluteString];
    if ([urlString containsString:@"supersonicads.com"] || [urlString containsString:@"unity3d.com"] || [urlString containsString:@"inmobi.com"]) {
        
        // تعديل الـ Request أو طباعة مسار الطلب للمراقبة
        NSMutableURLRequest *mutableReq = [request mutableCopy];
        [mutableReq setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 26_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
        
        return %orig(mutableReq, completionHandler);
    }
    
    return %orig;
}

%end

// هوك لتنظيف وتصفير العدادات والمعرفات تلقائياً عند الإقلاع وجلسات العمل
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. تصفير الحصص اليومية لمنع الرفض المحلي
        [defaults setInteger:0 forKey:@"RV_CappingManager.IS_CAPPED_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"IS_CappingManager.IS_DELETABLE_ENABLED_DefaultInterstitial"];
        [defaults setInteger:0 forKey:@"BN_CappingManager.IS_DELETABLE_DELAY_ENABLED_DefaultBanner"];
        
        // 2. تدوير وتوليد معرفات جديدة عشوائية لتجنب الحظر المعتمد على البصمة (Device ID Rotation)
        NSString *randomUUID = [[NSUUID UUID] UUIDString];
        [defaults setObject:randomUUID forKey:@"uuidStringFromStore"];
        [defaults setObject:randomUUID forKey:@"unityads-idfi"];
        
        // 3. مسح أي سجلات قديمة لجلسة المستخدم
        [defaults removeObjectForKey:@"User.id"];
        
        [defaults synchronize];
        NSLog(@"[Server-Bypass-Tweak] Network spoofing active and device fingerprints rotated successfully!");
    }
}
