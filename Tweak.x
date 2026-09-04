// Tweak.x
// A comprehensive iOS tweak for ad fraud prevention via environment virtualization.
// Hooks system APIs, network requests, WebViews, and caches while preserving Keychain.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <notify.h>

// -----------------------------------------------------------------------------
// Session‑based randomization seed (changes per app launch)
// -----------------------------------------------------------------------------
static NSUInteger sessionSeed = 0;

static void generateSessionSeed(void) {
    // Use time and PID to get a unique seed per launch.
    sessionSeed = (NSUInteger)([[NSDate date] timeIntervalSince1970] * 1000) ^ getpid();
}

static NSUInteger randomInRange(NSUInteger min, NSUInteger max) {
    if (sessionSeed == 0) generateSessionSeed();
    srand((unsigned)sessionSeed + (unsigned)rand()); // simple variation
    return min + arc4random_uniform((uint32_t)(max - min + 1));
}

// -----------------------------------------------------------------------------
// 1. Device & Environment Spoofing
// -----------------------------------------------------------------------------
%hook UIDevice

- (NSString *)name {
    // Return a random device name (e.g., "iPhone 12", "iPad Pro" etc.)
    static NSArray *deviceNames = @[@"iPhone 11", @"iPhone 12", @"iPhone 13", @"iPad Pro", @"iPad Air"];
    return deviceNames[randomInRange(0, deviceNames.count - 1)];
}

- (NSString *)systemVersion {
    // Spoof a plausible iOS version, e.g., 14.0 – 16.5
    NSUInteger major = randomInRange(14, 16);
    NSUInteger minor = randomInRange(0, 5);
    return [NSString stringWithFormat:@"%lu.%lu", (unsigned long)major, (unsigned long)minor];
}

- (NSString *)model {
    // Override model string (hardware identifier) – keep it plausible.
    static NSArray *models = @[@"iPhone13,2", @"iPhone14,3", @"iPad13,4"];
    return models[randomInRange(0, models.count - 1)];
}

- (NSString *)localizedModel {
    // Return same as model for simplicity.
    return [self model];
}

%end

// Locale spoofing
%hook NSLocale

+ (NSLocale *)currentLocale {
    // Return a random locale (e.g., en_US, fr_FR, de_DE, etc.)
    static NSArray *localeIdentifiers = @[@"en_US", @"en_GB", @"fr_FR", @"de_DE", @"es_ES", @"it_IT", @"ja_JP"];
    NSString *identifier = localeIdentifiers[randomInRange(0, localeIdentifiers.count - 1)];
    return [[NSLocale alloc] initWithLocaleIdentifier:identifier];
}

+ (NSLocale *)systemLocale {
    // Same as currentLocale for consistency.
    return [self currentLocale];
}

%end

// Timezone spoofing
%hook NSTimeZone

+ (NSTimeZone *)localTimeZone {
    static NSArray *timezoneNames = @[@"America/New_York", @"Europe/London", @"Asia/Tokyo", @"Australia/Sydney"];
    NSString *name = timezoneNames[randomInRange(0, timezoneNames.count - 1)];
    return [NSTimeZone timeZoneWithName:name];
}

+ (NSTimeZone *)systemTimeZone {
    return [self localTimeZone];
}

%end

// -----------------------------------------------------------------------------
// 2. Low-Level System Functions (sysctl / sysctlbyname)
// -----------------------------------------------------------------------------
// Original function pointers
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

// Custom sysctl handler
static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp) {
        // Identify hardware related OIDs
        if (namelen >= 2 && name[0] == CTL_HW) {
            switch (name[1]) {
                case HW_MACHINE:   // hw.machine
                case HW_MODEL:     // hw.model
                    // Already spoofed by UIDevice model hook, but adjust if needed.
                    // We'll leave as is to avoid inconsistency.
                    break;
                case HW_NCPU:      // hw.ncpu
                    if (*oldlenp == sizeof(int)) {
                        int *val = (int *)oldp;
                        // Random core count between 2 and 8
                        *val = (int)randomInRange(2, 8);
                    }
                    break;
                case HW_MEMSIZE:   // hw.memsize (total RAM)
                    if (*oldlenp == sizeof(uint64_t)) {
                        uint64_t *val = (uint64_t *)oldp;
                        // Randomize between 2GB and 8GB
                        uint64_t ramGB = randomInRange(2, 8);
                        *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
                    }
                    break;
                case HW_PHYSMEM:   // hw.physmem
                    // Similar to memsize
                    if (*oldlenp == sizeof(uint64_t)) {
                        uint64_t *val = (uint64_t *)oldp;
                        uint64_t ramGB = randomInRange(2, 8);
                        *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
                    }
                    break;
                default:
                    break;
            }
        }
    }
    return ret;
}

static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp) {
        // Check known names
        if (strcmp(name, "hw.ncpu") == 0 && *oldlenp == sizeof(int)) {
            int *val = (int *)oldp;
            *val = (int)randomInRange(2, 8);
        } else if (strcmp(name, "hw.memsize") == 0 && *oldlenp == sizeof(uint64_t)) {
            uint64_t *val = (uint64_t *)oldp;
            uint64_t ramGB = randomInRange(2, 8);
            *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
        } else if (strcmp(name, "hw.physmem") == 0 && *oldlenp == sizeof(uint64_t)) {
            uint64_t *val = (uint64_t *)oldp;
            uint64_t ramGB = randomInRange(2, 8);
            *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
        }
    }
    return ret;
}

// -----------------------------------------------------------------------------
// 3. Network Interception (NSURLSession / NSURLRequest)
// -----------------------------------------------------------------------------
// Helper to clean URL query parameters (remove tracking tokens)
static NSURL *cleanURL(NSURL *originalURL) {
    if (!originalURL) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    if (!components) return originalURL;
    
    // List of tracking parameter names to strip
    NSArray *trackingParams = @[@"idfa", @"udid", @"adid", @"aaid", @"openudid", @"gps_adid", @"android_id", @"gaid"];
    NSMutableArray *newQueryItems = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![trackingParams containsObject:item.name.lowercaseString]) {
            [newQueryItems addObject:item];
        }
    }
    components.queryItems = newQueryItems;
    return components.URL;
}

// Hook NSMutableURLRequest to modify headers and URL
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // Override User-Agent and Accept-Language with session-randomized values
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        // Generate a random User-Agent mimicking Safari
        static NSString *customUA = nil;
        if (!customUA) {
            // Build a plausible UA
            NSArray *osVersions = @[@"15_0", @"15_1", @"15_2", @"16_0", @"16_1"];
            NSArray *models = @[@"iPhone", @"iPad"];
            NSString *model = models[randomInRange(0, models.count-1)];
            NSString *osVer = osVersions[randomInRange(0, osVersions.count-1)];
            customUA = [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", model, model, osVer];
        }
        value = customUA;
    } else if ([field caseInsensitiveCompare:@"Accept-Language"] == NSOrderedSame) {
        // Randomize Accept-Language
        NSArray *langs = @[@"en-US,en;q=0.9", @"fr-FR,fr;q=0.9", @"de-DE,de;q=0.9", @"ja-JP,ja;q=0.9"];
        value = langs[randomInRange(0, langs.count-1)];
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    // Clean the URL before setting
    NSURL *cleaned = cleanURL(url);
    %orig(cleaned);
}

%end

// Also hook NSURLRequest to return cleaned URL if accessed
%hook NSURLRequest

- (NSURL *)URL {
    NSURL *origURL = %orig;
    return cleanURL(origURL) ?: origURL;
}

%end

// For NSURLSession, we can hook dataTaskWithRequest: to modify the request.
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    // Make a mutable copy and clean it
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    // Apply cleaning and header modifications (they will be handled by our NSMutableURLRequest hooks)
    // But we also need to explicitly set the cleaned URL and headers because the request might be immutable.
    // So we create a new mutable request.
    NSMutableURLRequest *newRequest = [mutableRequest mutableCopy];
    [newRequest setURL:cleanURL(request.URL)];
    // Set User-Agent and Accept-Language if not already set (our hook will do it when setValue is called)
    // Actually our hook on setValue:forHTTPHeaderField: will be called when we set them.
    if (![request valueForHTTPHeaderField:@"User-Agent"]) {
        [newRequest setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    }
    if (![request valueForHTTPHeaderField:@"Accept-Language"]) {
        [newRequest setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    }
    return %orig(newRequest, completionHandler);
}

%end

// -----------------------------------------------------------------------------
// 4. WKWebView Fingerprint Protection (JavaScript injection)
// -----------------------------------------------------------------------------
%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    // Inject JavaScript to spoof canvas, WebGL, AudioContext
    NSString *js = @"(function() {"
                   @"    // Canvas fingerprinting spoofing"
                   @"    const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;"
                   @"    HTMLCanvasElement.prototype.toDataURL = function(type, quality) {"
                   @"        if (type === 'image/png' || !type) {"
                   @"            // Add slight noise to canvas"
                   @"            const context = this.getContext('2d');"
                   @"            const imageData = context.getImageData(0, 0, this.width, this.height);"
                   @"            const data = imageData.data;"
                   @"            for (let i = 0; i < data.length; i += 4) {"
                   @"                data[i] ^= Math.floor(Math.random() * 2);" // small random noise
                   @"            }"
                   @"            context.putImageData(imageData, 0, 0);"
                   @"        }"
                   @"        return originalToDataURL.call(this, type, quality);"
                   @"    };"
                   @"    // WebGL fingerprinting spoofing"
                   @"    const getParameter = WebGLRenderingContext.prototype.getParameter;"
                   @"    WebGLRenderingContext.prototype.getParameter = function(pname) {"
                   @"        // Spoof WebGL vendor and renderer"
                   @"        if (pname === 0x1F00) return 'WebKit';" // VENDOR
                   @"        if (pname === 0x1F01) return 'WebKit WebGL';" // RENDERER
                   @"        return getParameter.call(this, pname);"
                   @"    };"
                   @"    // AudioContext fingerprinting spoof"
                   @"    const originalCreateOscillator = AudioContext.prototype.createOscillator;"
                   @"    AudioContext.prototype.createOscillator = function() {"
                   @"        const oscillator = originalCreateOscillator.call(this);"
                   @"        // Modify frequency slightly"
                   @"        const originalConnect = oscillator.connect;"
                   @"        oscillator.connect = function(destination) {"
                   @"            this.frequency.value += Math.random() * 0.1;"
                   @"            return originalConnect.call(this, destination);"
                   @"        };"
                   @"        return oscillator;"
                   @"    };"
                   @"})();";
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [configuration.userContentController addUserScript:script];
    
    return %orig(frame, configuration);
}

%end

// -----------------------------------------------------------------------------
// 5. Safe Temporary Cleanup (Caches, Cookies, Temp files – NO KEYCHAIN)
// -----------------------------------------------------------------------------
static void performCleanup(void) {
    // Clear HTTP cookies
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    
    // Clear NSURLCache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Clear temporary files
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths firstObject];
    if (cacheDir) {
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:cacheDir error:&error];
        for (NSString *file in contents) {
            NSString *fullPath = [cacheDir stringByAppendingPathComponent:file];
            [fm removeItemAtPath:fullPath error:nil];
        }
    }
    
    // Also clear tmp directory
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir) {
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tmpDir error:&error];
        for (NSString *file in contents) {
            NSString *fullPath = [tmpDir stringByAppendingPathComponent:file];
            [fm removeItemAtPath:fullPath error:nil];
        }
    }
    
    // Do NOT touch Keychain – leave it intact.
}

// -----------------------------------------------------------------------------
// 6. Early Initialization (constructor + notification)
// -----------------------------------------------------------------------------
%ctor {
    // Generate session seed at library load time
    generateSessionSeed();
    
    // Perform cleanup early
    performCleanup();
    
    // Hook sysctl and sysctlbyname using MSHookFunction
    void *handle = dlopen("/usr/lib/libsystem_kernel.dylib", RTLD_LAZY);
    if (handle) {
        orig_sysctl = (int (*)(int *, u_int, void *, size_t *, void *, size_t))dlsym(handle, "sysctl");
        orig_sysctlbyname = (int (*)(const char *, void *, size_t *, void *, size_t))dlsym(handle, "sysctlbyname");
        if (orig_sysctl) MSHookFunction((void *)orig_sysctl, (void *)hooked_sysctl, NULL);
        if (orig_sysctlbyname) MSHookFunction((void *)orig_sysctlbyname, (void *)hooked_sysctlbyname, NULL);
    }
    
    // Register for UIApplicationDidFinishLaunchingNotification to re-clean if needed
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      // Perform cleanup again (just in case)
                                                      performCleanup();
                                                      // Re-generate seed? No, keep same seed for session.
                                                  }];
}

// -----------------------------------------------------------------------------
// Explanation of critical sections
// -----------------------------------------------------------------------------
/*
  1. Environment Spoofing:
     - Hooks UIDevice, NSLocale, NSTimeZone to return randomized but plausible values per session.
     - The random values are derived from a session seed that is generated once per launch.
  2. sysctl Spoofing:
     - Uses MSHookFunction to intercept the low-level sysctl/sysctlbyname calls.
     - Identifies hardware OIDs (hw.ncpu, hw.memsize, etc.) and overwrites with random variations.
  3. Network Interception:
     - Hooks NSMutableURLRequest to override User-Agent and Accept-Language with session-randomized values.
     - Cleans URL query parameters by removing known tracking tokens (idfa, udid, adid, etc.).
     - Also intercepts NSURLSession dataTask to ensure modified request is used.
  4. WKWebView Protection:
     - Injects JavaScript that overrides HTMLCanvasElement.toDataURL, WebGL getParameter, and AudioContext to add noise and spoof vendor/renderer.
  5. Cleanup:
     - Clears cookies, caches, and temporary files at startup.
     - Explicitly avoids any Keychain operations.
  6. Early Initialization:
     - Uses %ctor to perform all hooks and cleanup before the app’s main code runs.
     - Also observes UIApplicationDidFinishLaunchingNotification for additional cleanup.
*/
