#import <Foundation/Foundation.h>

// دالة موحدة للتحقق من المفاتيح المطلوبة
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

// دالة تعيد القيمة المفروضة لكل مفتاح
static id forcedValueForKey(NSString *key) {
    if ([key isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"] ||
        [key isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        return @YES;
    }
    // الباقي كله NO (تعطيل الحظر والتوقيت)
    return @NO;
}

%hook NSUserDefaults

// اعتراض القراءة — هذا هو الجزء الحاسم
- (BOOL)boolForKey:(NSString *)key {
    if (isForcedKey(key)) {
        return [forcedValueForKey(key) boolValue];
    }
    return %orig;
}

- (id)objectForKey:(NSString *)key {
    if (isForcedKey(key)) {
        return forcedValueForKey(key);
    }
    return %orig;
}

// اعتراض الكتابة — منع الـ SDK من إعادة تفعيل الحظر
- (void)setBool:(BOOL)value forKey:(NSString *)key {
    if (isForcedKey(key)) {
        value = [forcedValueForKey(key) boolValue]; // نفرض قيمتنا مهما حاول يكتب
    }
    %orig(value, key);
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    if (isForcedKey(key)) {
        obj = forcedValueForKey(key);
    }
    %orig(obj, key);
}

// تصفير عداد الجلسات عند أي قراءة أو كتابة
- (NSInteger)integerForKey:(NSString *)key {
    if ([key isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        return 0;
    }
    return %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    if ([key isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0;
    }
    %orig(value, key);
}

%end

%ctor {
    @autoreleasepool {
        // نكتب القيم مبدئياً أيضاً (للتأكد من وجودها قبل أي قراءة)
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [d setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [d setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [d setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [d setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];

        NSLog(@"[AdForceGlobal] Hooks installed — ad constraints will stay forced forever");
    }
}
