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

#pragma mark - مسح ملفات plist (ينفذ يدوياً فقط)

static void wipeAllPlists(void) {
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];

        NSString *libDir    = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];

        NSArray *paths = @[
            [libDir stringByAppendingPathComponent:@"Preferences"],
            cachesDir
        ];

        int deletedCount = 0;

        for (NSString *basePath in paths) {
            if (!basePath || [basePath length] == 0 || ![fm fileExistsAtPath:basePath]) continue;

            NSMutableArray *toDelete = [NSMutableArray array];
            NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:basePath];
            NSString *relativePath;
            while ((relativePath = [enumerator nextObject]) != nil) {
                if ([relativePath.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                    [toDelete addObject:[basePath stringByAppendingPathComponent:relativePath]];
                }
            }

            for (NSString *fullPath in toDelete) {
                if ([fm removeItemAtPath:fullPath error:nil]) {
                    deletedCount++;
                }
            }
        }

        // إعادة كتابة القيم المفروضة بعد المسح
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [d setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [d setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [d setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];

        NSLog(@"[AdForceGlobal] Manual wipe done: %d plist files deleted", deletedCount);
    } @catch (NSException *e) {
        NSLog(@"[AdForceGlobal] Wipe failed safely: %@", e.reason);
    }
}

#pragma mark - اعتراض NSUserDefaults (نفس النسخة القديمة الشغالة)

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

#pragma mark - تفعيل المسح بالإيماءات

// 1) هز الجهاز = مسح فوري
%hook UIWindow

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        NSLog(@"[AdForceGlobal] Shake detected — wiping plists");
        wipeAllPlists();
    }
    %orig(motion, event);
}

// 2) لمس ثلاثي على الشاشة = مسح فوري
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(adForceTripleTapAction:)];
            tripleTap.numberOfTapsRequired = 3;
            tripleTap.numberOfTouchesRequired = 1;
            [[UIApplication sharedApplication].keyWindow addGestureRecognizer:tripleTap];
        });
    }
}

%new
- (void)adForceTripleTapAction:(UITapGestureRecognizer *)gesture {
    NSLog(@"[AdForceGlobal] Triple tap detected — wiping plists");
    wipeAllPlists();
}

%end

#pragma mark - التنفيذ

%ctor {
    @autoreleasepool {
        // كتابة القيم المفروضة فقط — بدون أي حذف ملفات هنا
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [d setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [d setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [d setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];

        NSLog(@"[AdForceGlobal] Tweak loaded — manual wipe mode (shake or triple-tap)");
    }
}
