#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 1. مراقبة كلاس المتجر وتسجيل كل حركة تحميل أو تفاعل
%hook StoreController
- (void)viewDidLoad {
    %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
    [defaults synchronize];
    NSLog(@"[AdDebug] StoreController -> viewDidLoad triggered. Session count forced to 0.");
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[AdDebug] StoreController -> viewDidAppear. Store screen is now active.");
}
%end

// 2. مراقبة وإدارة كلاس الإعلانات لضمان الجاهزية والتحميل المستمر
%hook InMobiInterstitial
- (BOOL)isReady {
    BOOL ready = %orig;
    NSLog(@"[AdDebug] InMobiInterstitial -> isReady called. Original state was: %@, forcing YES.", ready ? @"YES" : @"NO");
    return YES;
}

- (void)showFromViewController:(UIViewController *)viewController {
    NSLog(@"[AdDebug] InMobiInterstitial -> showFromViewController called successfully!");
    %orig;
    
    // إجبار الإعلان على إعادة التحميل فوراً بعد عرضه ليكون جاهزاً للمرة القادمة دون انتظار
    @try {
        if ([self respondsToSelector:@selector(load)]) {
            [self performSelector:@selector(load) withObject:nil afterDelay:0.4];
            NSLog(@"[AdDebug] Triggered [self load] successfully after showing ad.");
        }
    } @catch (NSException *exception) {
        NSLog(@"[AdDebug] Error reloading ad: %@", exception.reason);
    }
}
%end

// مراقبة مدير الإعلانات الداخلي إن وجد لتحفيز جلب الإعلانات
%hook InMobiAdManager
- (void)loadAd {
    %orig;
    NSLog(@"[AdDebug] InMobiAdManager -> loadAd called.");
}
%end

// 3. مراقبة وتعديل NSUserDefaults بشكل شامل (شملنا integerForKey وتغيير unityads-idfi)
%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName containsString:@"Capping"] || [defaultName containsString:@"delivery"]) {
        NSLog(@"[AdDebug] NSUserDefaults setBool: %@ for key: %@", value ? @"YES" : @"NO", defaultName);
    }
    
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) {
        value = YES;
    }
    else if ([defaultName isEqualToString:@"BN_CategoryManager.IS_CAPPING_ENABLED_DefaultBanner"] || [defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        value = YES;
    }
    %orig(value, defaultName);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        NSLog(@"[AdDebug] NSUserDefaults trying to change sessionCount to: %ld. Blocking & resetting to 0.", (long)value);
        value = 0;
    }
    %orig(value, defaultName);
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        NSLog(@"[AdDebug] NSUserDefaults integerForKey: %@ -> forced to return 0", defaultName);
        return 0;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    // تزوير واقتناص مفتاح unityads-idfi وتوليد معرف عشوائي جديد لتجاوز الحظر
    if ([defaultName isEqualToString:@"unityads-idfi"]) {
        NSString *randomID = [[NSUUID UUID] UUIDString];
        NSLog(@"[AdDebug] Intercepted unityads-idfi. Changing from %@ to new random ID: %@", value, randomID);
        value = randomID;
    }
    %orig(value, defaultName);
}

- (id)objectForKey:(NSString *)defaultName {
    id val = %orig;
    if ([defaultName containsString:@"sessionCount"] || [defaultName containsString:@"Capping"] || [defaultName isEqualToString:@"unityads-idfi"]) {
        NSLog(@"[AdDebug] NSUserDefaults objectForKey: %@ -> value: %@", defaultName, val);
    }
    return val;
}

%end

// 4. دالة التهيئة العامة وتسجيل حالة البدء
%ctor {
    @autoreleasepool {
        NSLog(@"[AdDebug] Tweak loaded into process successfully!");
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        // توليد هوية جديدة لـ unityads-idfi فور تشغيل التطبيق لتفادي حد الإعلانات
        [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"unityads-idfi"];
        
        [defaults synchronize];
    }
}
