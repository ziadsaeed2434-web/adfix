#import <AVFoundation/AVFoundation.h>

// اعتراض أي مشغل فيديو (AVPlayer) يبدأ داخل التطبيق (والذي تستخدمه إعلانات Unity لتشغيل الفيديو)
%hook AVPlayer

- (void)play {
    %orig;
    // التحقق إذا كان المشغل يخص إعلانات أو رابط إعلاني، نقوم بمضاعفة السرعة
    // أو يمكننا تطبيق السرعة على جميع مشغلات الفيديو الخاصة بالإعلانات فوراً
    self.rate = 8.0; // تسريع الفيديو إلى 8 أضعاف سرعته الطبيعية! (سينتهي إعلان الـ 30 ثانية في أقل من 4 ثوانٍ)
}

- (void)setRate:(float)rate {
    // إجبار السرعة على البقاء عالية حتى لو حاول مشغل الإعلان إعادتها للوضع الطبيعي (1.0)
    if (rate < 8.0) {
        %orig(8.0);
    } else {
        %orig(rate);
    }
}

%end

// اعتراض مشغلات الويب الخاصة بـ Unity Ads لزيادة سرعة وسائط الفيديو إن وجدت
%hook UADSWebView

- (void)webView:(id)arg1 didFinishNavigation:(id)arg2 {
    %orig;
    // حقن سكربت JavaScript يسرع أي عنصر فيديو (HTML5 Video) موجود داخل إعلان الـ WebView
    NSString *speedScript = @"var videos = document.querySelectorAll('video'); for(var i=0; i<videos.length; i++){ videos[i].playbackRate = 8.0; videos[i].muted = true; }";
    [self evaluateJavaScript:speedScript completionHandler:nil];
}

%end
