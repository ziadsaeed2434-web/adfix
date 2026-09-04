// Tweak.x - بدون تزييف UIDevice، فقط تزييف الشبكة و WebView
// يحافظ على الإعلانات عن طريق تغيير قيم التتبع بدلاً من حذفها

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// =====================================================================
// 1. ثوابت البيانات المزيفة (للهوكات المتأخرة فقط)
// =====================================================================
static NSString * const acceptLanguages[] = {
    @"en-US,en;q=0.9", @"fr-FR,fr;q=0.9", @"de-DE,de;q=0.9", @"ja-JP,ja;q=0.9"
};
static const NSUInteger acceptLanguagesCount = sizeof(acceptLanguages)/sizeof(acceptLanguages[0]);

static NSString * const osVersions[] = { @"15_0", @"15_1", @"15_2", @"16_0", @"16_1" };
static const NSUInteger osVersionsCount = sizeof(osVersions)/sizeof(osVersions[0]);

static NSString * const uaModels[] = { @"iPhone", @"iPad" };
static const NSUInteger uaModelsCount = sizeof(uaModels)/sizeof(uaModels[0]);

// =====================================================================
// 2. بذرة العشوائية
// =====================================================================
static NSUInteger sessionSeed = 0;

static void generateSessionSeed(void) {
    sessionSeed = (NSUInteger)([[NSDate date] timeIntervalSince1970] * 1000) ^ getpid();
}

static NSUInteger randomInRange(NSUInteger min, NSUInteger max) {
    if (sessionSeed == 0) generateSessionSeed();
    srand((unsigned)sessionSeed + (unsigned)rand());
    return min + arc4random_uniform((uint32_t)(max - min + 1));
}

// توليد معرف عشوائي (مثل IDFA وهمي)
static NSString *randomIDFA(void) {
    return [NSString stringWithFormat:@"%08X-%04X-%04X-%04X-%012X",
            (unsigned)arc4random(), (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random() & 0xFFFF,
            (unsigned)arc4random()];
}

// =====================================================================
// 3. هوك UIDevice ملغي (لا نقوم بتزويره)
// =====================================================================
// تم إزالة %hook UIDevice بالكامل

// =====================================================================
// 4. مجموعة الهوكات المتأخرة (تُفعَّل بعد 3 ثوانٍ)
// =====================================================================
%group DelayedHooks

// 4.1 تزييف معلمات التتبع (تغيير القيم بدلاً من حذفها)
static NSURL *spoofURL(NSURL *originalURL) {
    if (!originalURL) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    if (!components) return originalURL;
    
    // قائمة بارامترات التتبع التي نريد تزييفها
    NSArray *trackingParams = @[@"idfa", @"udid", @"adid", @"aaid", @"openudid", @"gps_adid", @"android_id", @"gaid"];
    NSMutableArray *newQueryItems = [NSMutableArray array];
    
    for (NSURLQueryItem *item in components.queryItems) {
        if ([trackingParams containsObject:item.name.lowercaseString]) {
            // استبدال القيمة بقيمة عشوائية (مثل IDFA وهمي)
            NSString *newValue = randomIDFA();
            NSURLQueryItem *newItem = [NSURLQueryItem queryItemWithName:item.name value:newValue];
            [newQueryItems addObject:newItem];
        } else {
            [newQueryItems addObject:item];
        }
    }
    components.queryItems = newQueryItems;
    return components.URL;
}

// 4.2 هوك NSMutableURLRequest (تغيير User-Agent و Accept-Language وتزييف المعلمات)
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        static NSString *customUA = nil;
        if (!customUA) {
            NSString *model = uaModels[randomInRange(0, uaModelsCount - 1)];
            NSString *osVer = osVersions[randomInRange(0, osVersionsCount - 1)];
            customUA = [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", model, model, osVer];
        }
        value = customUA;
    } else if ([field caseInsensitiveCompare:@"Accept-Language"] == NSOrderedSame) {
        value = acceptLanguages[randomInRange(0, acceptLanguagesCount - 1)];
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

// 4.4 هوك WKWebView (حقن JavaScript لحماية البصمة)
%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    NSString *js = @"(function(){"
                   @"const orig=HTMLCanvasElement.prototype.toDataURL;"
                   @"HTMLCanvasElement.prototype.toDataURL=function(t,q){"
                   @" if(t==='image/png'||!t){"
                   @"  const ctx=this.getContext('2d'), img=ctx.getImageData(0,0,this.width,this.height), d=img.data;"
                   @"  for(let i=0;i<d.length;i+=4)d[i]^=Math.random()*2|0;"
                   @"  ctx.putImageData(img,0,0);"
                   @" } return orig.call(this,t,q);"
                   @"};"
                   @"const gp=WebGLRenderingContext.prototype.getParameter;"
                   @"WebGLRenderingContext.prototype.getParameter=function(p){"
                   @" if(p===0x1F00)return'WebKit';"
                   @" if(p===0x1F01)return'WebKit WebGL';"
                   @" return gp.call(this,p);"
                   @"};"
                   @"const oc=AudioContext.prototype.createOscillator;"
                   @"AudioContext.prototype.createOscillator=function(){"
                   @" const o=oc.call(this), oc2=o.connect;"
                   @" o.connect=function(d){this.frequency.value+=Math.random()*0.1; return oc2.call(this,d);};"
                   @" return o;"
                   @"};})();";
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [configuration.userContentController addUserScript:script];
    return %orig(frame, configuration);
}
%end

%end // DelayedHooks

// =====================================================================
// 5. التهيئة الرئيسية (بدون أي هوك فوري)
// =====================================================================
%ctor {
    generateSessionSeed();
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
