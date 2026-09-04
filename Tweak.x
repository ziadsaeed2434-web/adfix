// Tweak.x - نسخة مستقرة وآمنة للبدء

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <sys/sysctl.h>
#import <dlfcn.h>

// =====================================================================
// ثوابت C arrays (آمنة للاستخدام في النطاق العام)
// =====================================================================
static NSString * const deviceNames[] = {
    @"iPhone 11", @"iPhone 12", @"iPhone 13", @"iPad Pro", @"iPad Air"
};
static const NSUInteger deviceNamesCount = sizeof(deviceNames)/sizeof(deviceNames[0]);

static NSString * const models[] = {
    @"iPhone13,2", @"iPhone14,3", @"iPad13,4"
};
static const NSUInteger modelsCount = sizeof(models)/sizeof(models[0]);

static NSString * const acceptLanguages[] = {
    @"en-US,en;q=0.9", @"fr-FR,fr;q=0.9", @"de-DE,de;q=0.9", @"ja-JP,ja;q=0.9"
};
static const NSUInteger acceptLanguagesCount = sizeof(acceptLanguages)/sizeof(acceptLanguages[0]);

static NSString * const osVersions[] = { @"15_0", @"15_1", @"15_2", @"16_0", @"16_1" };
static const NSUInteger osVersionsCount = sizeof(osVersions)/sizeof(osVersions[0]);

static NSString * const uaModels[] = { @"iPhone", @"iPad" };
static const NSUInteger uaModelsCount = sizeof(uaModels)/sizeof(uaModels[0]);

// =====================================================================
// بذرة العشوائية لكل جلسة
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

// =====================================================================
// 1. هوك بسيط لـ UIDevice (تجنب هوكات NSLocale و NSTimeZone)
// =====================================================================
%hook UIDevice
- (NSString *)name {
    return deviceNames[randomInRange(0, deviceNamesCount - 1)];
}
- (NSString *)systemVersion {
    NSUInteger major = randomInRange(14, 16);
    NSUInteger minor = randomInRange(0, 5);
    return [NSString stringWithFormat:@"%lu.%lu", major, minor];
}
- (NSString *)model {
    return models[randomInRange(0, modelsCount - 1)];
}
%end

// =====================================================================
// 2. هوك sysctl (مع تحقق من صحة البيانات)
// =====================================================================
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp && *oldlenp > 0) {
        if (namelen >= 2 && name[0] == CTL_HW) {
            if (name[1] == HW_NCPU && *oldlenp == sizeof(int)) {
                *(int *)oldp = (int)randomInRange(2, 8);
            } else if ((name[1] == HW_MEMSIZE || name[1] == HW_PHYSMEM) && *oldlenp == sizeof(uint64_t)) {
                uint64_t ramGB = randomInRange(2, 8);
                *(uint64_t *)oldp = ramGB * 1024ULL * 1024ULL * 1024ULL;
            }
        }
    }
    return ret;
}

static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp && *oldlenp > 0) {
        if (strcmp(name, "hw.ncpu") == 0 && *oldlenp == sizeof(int)) {
            *(int *)oldp = (int)randomInRange(2, 8);
        } else if ((strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) && *oldlenp == sizeof(uint64_t)) {
            uint64_t ramGB = randomInRange(2, 8);
            *(uint64_t *)oldp = ramGB * 1024ULL * 1024ULL * 1024ULL;
        }
    }
    return ret;
}

// =====================================================================
// 3. هوكات الشبكة (مع تأخير)
// =====================================================================
static void setupNetworkHooks(void) {
    %init(NSMutableURLRequest);
    %init(NSURLRequest);
    %init(NSURLSession);
}

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
%end

// =====================================================================
// 4. هوك WKWebView (حقن JavaScript)
// =====================================================================
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

// =====================================================================
// 5. وظيفة التنظيف الآمنة (بدون Keychain)
// =====================================================================
static void performCleanup(void) {
    // حذف الكوكيز
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in cookieStorage.cookies) {
        [cookieStorage deleteCookie:cookie];
    }
    // حذف ذاكرة التخزين المؤقت
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    // حذف الملفات المؤقتة
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (cacheDir) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:cacheDir error:nil]) {
            [fm removeItemAtPath:[cacheDir stringByAppendingPathComponent:file] error:nil];
        }
    }
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:tmpDir error:nil]) {
            [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
        }
    }
}

// =====================================================================
// 6. التهيئة المبكرة (آمنة)
// =====================================================================
%ctor {
    generateSessionSeed();
    
    // تهيئة هوك sysctl
    void *handle = dlopen("/usr/lib/libsystem_kernel.dylib", RTLD_LAZY);
    if (handle) {
        orig_sysctl = (int (*)(int *, u_int, void *, size_t *, void *, size_t))dlsym(handle, "sysctl");
        orig_sysctlbyname = (int (*)(const char *, void *, size_t *, void *, size_t))dlsym(handle, "sysctlbyname");
        if (orig_sysctl) MSHookFunction((void *)orig_sysctl, (void *)hooked_sysctl, NULL);
        if (orig_sysctlbyname) MSHookFunction((void *)orig_sysctlbyname, (void *)hooked_sysctlbyname, NULL);
    }
    
    // تأخير تهيئة باقي الهوكسات والتنظيف إلى ما بعد الإطلاق
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      performCleanup();
                                                      setupNetworkHooks(); // هوكات الشبكة بعد التهيئة
                                                  }];
}
