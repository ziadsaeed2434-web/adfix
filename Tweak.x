// Tweak.x - تزييف لكل جلسة (بدون UIDevice)
// يتم توليد قيم جديدة لكل إطلاق للتطبيق وتثبيتها طوال الجلسة
// لا يتم حذف أي ملفات أو كوكيز

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// =====================================================================
// 1. قوائم البيانات (تُستخدم لتوليد القيم العشوائية)
// =====================================================================
static NSString * const acceptLanguages[] = {
    @"en-US,en;q=0.9", @"fr-FR,fr;q=0.9", @"de-DE,de;q=0.9", @"ja-JP,ja;q=0.9",
    @"ar-SA,ar;q=0.9", @"es-ES,es;q=0.9", @"zh-CN,zh;q=0.9"
};
static const NSUInteger acceptLanguagesCount = sizeof(acceptLanguages)/sizeof(acceptLanguages[0]);

static NSString * const osVersions[] = {
    @"14_0", @"14_1", @"14_2", @"15_0", @"15_1", @"15_2", @"16_0", @"16_1", @"16_2"
};
static const NSUInteger osVersionsCount = sizeof(osVersions)/sizeof(osVersions[0]);

static NSString * const uaModels[] = { @"iPhone", @"iPad", @"iPod" };
static const NSUInteger uaModelsCount = sizeof(uaModels)/sizeof(uaModels[0]);

// =====================================================================
// 2. متغيرات الجلسة (تُولَّد مرة واحدة عند بدء التطبيق)
// =====================================================================
static NSString *sessionUserAgent = nil;
static NSString *sessionAcceptLanguage = nil;
static NSString *sessionIDFA = nil;

// دوال مساعدة للتوليد
static NSUInteger randomInRange(NSUInteger min, NSUInteger max) {
    return min + arc4random_uniform((uint32_t)(max - min + 1));
}

static NSString *generateRandomUserAgent(void) {
    NSString *model = uaModels[randomInRange(0, uaModelsCount - 1)];
    NSString *osVer = osVersions[randomInRange(0, osVersionsCount - 1)];
    return [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/%lu.0 Mobile/15E148 Safari/604.1",
            model, model, osVer, (unsigned long)randomInRange(14, 17)];
}

static NSString *generateRandomAcceptLanguage(void) {
    return acceptLanguages[randomInRange(0, acceptLanguagesCount - 1)];
}

static NSString *generateRandomIDFA(void) {
    return [NSString stringWithFormat:@"%08X-%04X-%04X-%04X-%012X",
            (unsigned)arc4random(), (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random()];
}

// توليد جميع قيم الجلسة
static void generateSessionValues(void) {
    sessionUserAgent = generateRandomUserAgent();
    sessionAcceptLanguage = generateRandomAcceptLanguage();
    sessionIDFA = generateRandomIDFA();
}

// =====================================================================
// 3. هوك UIDevice (ملغي تماماً - لا نزيف)
// =====================================================================
// تم إزالة %hook UIDevice بالكامل

// =====================================================================
// 4. مجموعة الهوكات المتأخرة (تُفعَّل بعد 3 ثوانٍ)
// =====================================================================
%group DelayedHooks

// 4.1 تزييف معلمات التتبع في URLs (باستخدام sessionIDFA الثابت)
static NSURL *spoofURL(NSURL *originalURL) {
    if (!originalURL) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    if (!components) return originalURL;
    
    NSArray *trackingParams = @[@"idfa", @"udid", @"adid", @"aaid", @"openudid", @"gps_adid", @"android_id", @"gaid", @"device_id"];
    NSMutableArray *newQueryItems = [NSMutableArray array];
    
    for (NSURLQueryItem *item in components.queryItems) {
        if ([trackingParams containsObject:item.name.lowercaseString]) {
            // استخدام نفس المعرف طوال الجلسة
            NSURLQueryItem *newItem = [NSURLQueryItem queryItemWithName:item.name value:sessionIDFA];
            [newQueryItems addObject:newItem];
        } else {
            [newQueryItems addObject:item];
        }
    }
    components.queryItems = newQueryItems;
    return components.URL;
}

// 4.2 هوك NSMutableURLRequest (يستخدم قيم الجلسة الثابتة)
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        value = sessionUserAgent ?: value;
    } else if ([field caseInsensitiveCompare:@"Accept-Language"] == NSOrderedSame) {
        value = sessionAcceptLanguage ?: value;
    }
    %orig(value, field);
}
- (void)setURL:(NSURL *)url {
    NSURL *spoofed = spoofURL(url);
    %orig(spoofed);
}
%end

// 4.3 هوك NSURLRequest (لضمان تزييف الرابط عند قراءته)
%hook NSURLRequest
- (NSURL *)URL {
    NSURL *origURL = %orig;
    return spoofURL(origURL) ?: origURL;
}
%end

// 4.4 هوك WKWebView (حقن JavaScript لتشويش البصمة)
%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    // إضافة تشويش يعتمد على رقم عشوائي ثابت للجلسة
    NSString *randomNoise = [NSString stringWithFormat:@"%d", (int)arc4random() % 100];
    NSString *js = [NSString stringWithFormat:@"(function(){"
                   @"const orig=HTMLCanvasElement.prototype.toDataURL;"
                   @"HTMLCanvasElement.prototype.toDataURL=function(t,q){"
                   @" if(t==='image/png'||!t){"
                   @"  const ctx=this.getContext('2d'), img=ctx.getImageData(0,0,this.width,this.height), d=img.data;"
                   @"  for(let i=0;i<d.length;i+=4)d[i]^=Math.random()*3|0;"
                   @"  ctx.putImageData(img,0,0);"
                   @" } return orig.call(this,t,q);"
                   @"};"
                   @"const gp=WebGLRenderingContext.prototype.getParameter;"
                   @"WebGLRenderingContext.prototype.getParameter=function(p){"
                   @" if(p===0x1F00)return 'WebKit' + %@;"
                   @" if(p===0x1F01)return 'WebKit WebGL' + %@;"
                   @" return gp.call(this,p);"
                   @"};"
                   @"const oc=AudioContext.prototype.createOscillator;"
                   @"AudioContext.prototype.createOscillator=function(){"
                   @" const o=oc.call(this), oc2=o.connect;"
                   @" o.connect=function(d){this.frequency.value+=Math.random()*0.5; return oc2.call(this,d);};"
                   @" return o;"
                   @"};})();", randomNoise, randomNoise];
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [configuration.userContentController addUserScript:script];
    return %orig(frame, configuration);
}
%end

%end // DelayedHooks

// =====================================================================
// 5. التهيئة الرئيسية
// =====================================================================
%ctor {
    // توليد قيم الجلسة الجديدة فور تحميل الت tweak
    generateSessionValues();
    
    // لا نفعّل أي هوك فوراً (UIDevice ملغي)
    
    // تأجيل الهوكات الحساسة إلى ما بعد إطلاق التطبيق
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            %init(DelayedHooks);
        });
    }];
}
