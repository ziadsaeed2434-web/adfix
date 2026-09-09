#import <Foundation/Foundation.h>

static BOOL isForcedKey(NSString *key) {
    if (!key) return NO; // حماية ضد nil
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

// كتابة القيم المبدئية — تتأجل للـ main queue حتى ما يصير كراش
static void forceInitialValues(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
    [d setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
    [d setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
    [d setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
    [d setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
    [d setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
    NSLog(@"[AdForceGlobal] Initial values forced");
}

%ctor {
    @autoreleasepool {
        NSLog(@"[AdForceGlobal] Tweak loaded");

        // نؤجل الكتابة للـ main queue — الحل الأساسي للكراش
        dispatch_async(dispatch_get_main_queue(), ^{
            forceInitialValues();
        });
    }
}
