#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// دالة مخصصة لتنفيذ عملية المسح الشامل ومحاكاة الحذف والتثبيت
void performDeepCleanSimulation() {
    @autoreleasepool {
        NSLog(@"[AdDebug] Background clean trigger: Simulating clean app reinstall on exit!");
        
        // أ) مسح مجلد الـ Caches الخاص بالتطبيق
        NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cachesPaths objectAtIndex:0];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:&error];
        for (NSString *file in cacheFiles) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:filePath error:&error];
        }
        
        // ب) مسح الملفات المؤقتة في مجلد tmp
        NSString *tmpDirectory = NSTemporaryDirectory();
        NSArray *tmpFiles = [fileManager contentsOfDirectoryAtPath:tmpDirectory error:&error];
        for (NSString *file in tmpFiles) {
            NSString *filePath = [tmpDirectory stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:filePath error:&error];
        }
        
        // ج) مسح نطاقات InMobi و Unity و Capping من NSUserDefaults وتوليد هوية جديدة
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dict = [defaults dictionaryRepresentation];
        for (NSString *key in dict) {
            if ([key containsString:@"inobi"] || [key containsString:@"unity"] || [key containsString:@"Capping"] || [key containsString:@"delivery"]) {
                [defaults removeObjectForKey:key];
            }
        }
        
        // ضبط القيم الجديدة النظيفة
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        NSString *freshIDFI = [[NSUUID UUID] UUIDString];
        [defaults setObject:freshIDFI forKey:@"unityads-idfi"];
        
        [defaults synchronize];
        NSLog(@"[AdDebug] Background cleanup complete. New IDFI prepared for next launch: %@", freshIDFI);
    }
}

// 1. مراقبة كلاس المتجر لتصفير العداد فور ظهوره
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

// 2. مراقبة وإدارة كلاسات InMobi الحقيقية لضمان الجاهزية
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

// 3. مراقبة وتعديل NSUserDefaults بشكل شامل
%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *__strong)defaultName {
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

- (void)setInteger:(NSInteger)value forKey:(NSString *__strong)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0;
    }
    %orig(value, defaultName);
}

- (NSInteger)integerForKey:(NSString *__strong)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        return 0;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *__strong)defaultName {
    if ([defaultName isEqualToString:@"unityads-idfi"]) {
        value = [[NSUUID UUID] UUIDString];
    }
    %orig(value, defaultName);
}

%end

// 4. مراقبة دورة حياة التطبيق لتنفيذ المسح الشامل فور الخروج إلى الخلفية أو الإغلاق
%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            NSLog(@"[AdDebug] App entered background. Executing clean simulation...");
            performDeepCleanSimulation(); // تم تصحيح اسم الدالة هنا لتتطابق تماماً
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            NSLog(@"[AdDebug] App will terminate. Executing final clean simulation...");
            performDeepCleanSimulation(); // وتم تصحيح اسم الدالة هنا أيضاً
        }];
    }
}
