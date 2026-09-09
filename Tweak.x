#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - المفاتيح المفروضة

static BOOL isForcedKey(NSString *key) {
    static NSSet *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[
            @"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial",
            @"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial",
            @"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner",
            @"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner",
            @"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"
        ]];
    });
    return [keys containsObject:key];
}

static id forcedValueForKey(NSString *key) {
    if ([key isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"] ||
        [key isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        return @YES;
    }
    return @NO;
}

#pragma mark - مسح كل ملفات plist

static void wipeAllPlists(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    // المسارات التي نمسح منها كل الـ plists
    NSArray *paths = @[
        // الأهم: هنا يخزن NSUserDefaults ومعظم الـ SDKs عدّاداتها
        [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Preferences"],
        // بعض الـ SDKs تخزن في مجلد Library مباشرة
        NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject,
        // Application Support
        [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject],
        // Caches
        [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject],
        // Documents
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject]
    ];

    int deletedCount = 0;

    for (NSString *basePath in paths) {
        if (!basePath || ![fm fileExistsAtPath:basePath]) continue;

        // المسح العميق: نمسح كل plist في المجلد وكل المجلدات الفرعية
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:basePath];
        NSString *relativePath;
        while ((relativePath = [enumerator nextObject]) != nil) {
            if ([relativePath.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                NSString *fullPath = [basePath stringByAppendingPathComponent:relativePath];
                if ([fm removeItemAtPath:fullPath error:nil]) {
                    deletedCount++;
                    NSLog(@"[AdForceGlobal] Deleted plist: %@", fullPath);
                }
            }
        }
    }

    // أيضاً نمسح الـ NSUserDefaults الداخلي نفسه
    NSString *appBundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *prefsPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", appBundleID];
    if ([fm fileExistsAtPath:prefsPath]) {
        [fm removeItemAtPath:prefsPath error:nil];
        deletedCount++;
        NSLog(@"[AdForceGlobal] Deleted global prefs: %@", prefsPath);
    }

    // إعادة كتابة القيم المفروضة بعد المسح
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
    [d setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
    [d setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
    [d setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
    [d setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
    [d setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];

    NSLog(@"[AdForceGlobal] Wiped %d plist files, values re-forced", deletedCount);
}

#pragma mark - اعتراض NSUserDefaults

%hook NSUserDefaults

- (BOOL)boolForKey:(NSString *)key {
    if (isForcedKey(key)) return [forcedValueForKey(key) boolValue];
    return %orig;
}

- (id)objectForKey:(NSString *)key {
    if (isForcedKey(key)) return forcedValueForKey(key);
    return %orig;
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    if (isForcedKey(key)) value = [forcedValueForKey(key) boolValue];
    %orig(value, key);
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    if (isForcedKey(key)) obj = forcedValueForKey(key);
    %orig(obj, key);
}

- (NSInteger)integerForKey:(NSString *)key {
    if ([key isEqualToString:@"com.inobi_defaultStore_sessionCount"]) return 0;
    return %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    if ([key isEqualToString:@"com.inobi_defaultStore_sessionCount"]) value = 0;
    %orig(value, key);
}

%end

#pragma mark - التنفيذ

%ctor {
    @autoreleasepool {
        NSLog(@"[AdForceGlobal] Tweak loaded — full plist wipe mode");

        // مسح فوري عند تحميل التويك
        wipeAllPlists();

        // مسح عند كل فتح للتطبيق
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                            object:nil queue:nil
                                                      usingBlock:^(NSNotification *n) {
            wipeAllPlists();
        }];

        // مسح عند كل عودة من الخلفية
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                            object:nil queue:nil
                                                      usingBlock:^(NSNotification *n) {
            wipeAllPlists();
        }];
    }
}
