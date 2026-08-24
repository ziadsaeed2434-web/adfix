#import <WebKit/WebKit.h>

// تسريع أوقات وحركات الإعلانات التفاعلية (Playable Ads) حصرياً
%hook WKWebView

- (void)layoutSubviews {
    %orig;
    
    // سكربت JavaScript يسرع دورات الـ Animation والمؤقتات داخل الإعلان التفاعلي
    NSString *speedUpScript = 
    @"if (!window._isSpeedUpInjected) {"
    "   window._isSpeedUpInjected = true;"
    "   "
    "   // تسريع الحركات والعروض المرئية بداخل الإعلان"
    "   var originalRAF = window.requestAnimationFrame;"
    "   window.requestAnimationFrame = function(callback) {"
    "       return originalRAF(function() {"
    "           callback();"
    "           callback();" // تسريع الإطار مرتين
    "           callback();" // تسريع الإطار 3 مرات لتنتهي اللعبة المصغرة فوراً
    "       });"
    "   };"
    "   "
    "   // تقليص وتقريب أوقات الانتظار والمؤقتات الداخلية (Timers) إلى أقصى سرعة"
    "   var originalSetTimeout = window.setTimeout;"
    "   window.setTimeout = function(func, delay) {"
    "       return originalSetTimeout(func, 10); " // جعل أي انتظار ينتهي في 10 ملي ثانية فقط
    "   };"
    "}";
    
    [self evaluateJavaScript:speedUpScript completionHandler:nil];
}

%end
