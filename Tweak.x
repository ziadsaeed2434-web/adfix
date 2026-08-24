#import <WebKit/WebKit.h>

%hook WKWebView

- (void)layoutSubviews {
    %orig;
    
    // سكربت لإجبار عناصر الإغلاق والتخطي المخفية على الظهور والتفعيل فوراً
    NSString *forceUnlockScript = 
    @"var allElements = document.querySelectorAll('*');"
     "for (var i = 0; i < allElements.length; i++) {"
     "   var el = allElements[i];"
     "   var cls = el.className ? el.className.toString().toLowerCase() : '';"
     "   var id = el.id ? el.id.toString().toLowerCase() : '';"
     "   "
     "   // البحث عن أي عنصر له علاقة بالإغلاق، التخطي، أو الـ Close حتى لو كان مخفياً"
     "   if (cls.includes('close') || cls.includes('skip') || cls.includes('dismiss') || id.includes('close') || id.includes('skip') || el.innerText === 'X' || el.innerText === '×') {"
     "       el.style.display = 'block';"
     "       el.style.visibility = 'visible';"
     "       el.style.opacity = '1';"
     "       el.style.pointerEvents = 'auto';"
     "       el.click();"
     "   }"
    "}";
    
    [self evaluateJavaScript:forceUnlockScript completionHandler:nil];
}

%end
