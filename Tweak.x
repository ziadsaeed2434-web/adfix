#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 1. مراقبة كلاس المتجر وتصفير العداد عند ظهور الشاشة
%hook StoreController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
    [defaults synchronize];
    NSLog(@"[AdDebug] StoreController -> viewWillAppear triggered. Session count forced to 0.");
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[AdDebug] StoreController -> viewDidAppear. Store screen is now active.");
}
%end

// 2. مراقبة وإدارة كلاسات InMobi الحقيقية المستخرجة من Runtime Browser لضمان الجاهزية
%hook IMOMAdSessionManager

- (BOOL)isReady {
    BOOL ready = %orig;
    NSLog(@"[AdDebug] IMOMAdSessionManager -> isReady called. Original state was: %@, forcing YES.", ready ? @"YES" : @"NO");
    return YES;
}

- (void)loadAd {
    %orig;
    NSLog(@"[AdDebug] IMOMAdSessionManager -> loadAd called.");
}

%end

// هوك إضافي لمراقبة واجهات العرض والرندرة الخاصة بالإعلانات
%hook IMRenderViewController

- (void)viewDidLoad {
    %orig;
    NSLog(@"[AdDebug] IMRenderViewController -> viewDidLoad called.");
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[AdDebug] IMRenderViewController -> viewDidAppear. Ad view is now active.");
}

%end

// 3. مراقبة وتعديل NSUserDefaults بشكل شامل (Capping & IDFI)
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

// 4. دالة التهيئة العامة: تعمل في كل مرة يُفتح فيها التطبيق من الصفر لتعمل كأنها أول تثبيت
%ctor {
    @autoreleasepool {
        NSLog(@"[AdDebug] Fresh start triggered: Tweak simulating first-time launch!");
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // مسح القيم القديمة تماماً لضمان بداية نظيفة
        [defaults removeObjectForKey:@"com.inobi_defaultStore_sessionCount"];
        [defaults removeObjectForKey:@"unityads-idfi"];
        
        // ضبط القيم الافتراضية لتجاوز القيود
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        // توليد هوية جديدة بالكامل (UUID) مع كل فتحة جديدة للتطبيق
        NSString *freshIDFI = [[NSUUID UUID] UUIDString];
        [defaults setObject:freshIDFI forKey:@"unityads-idfi"];
        
        [defaults synchronize];
        NSLog(@"[AdDebug] Generated brand new unityads-idfi on launch: %@", freshIDFI);
    }
}
