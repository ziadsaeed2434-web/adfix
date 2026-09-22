// AdBypassTweak.xm
// تويك شامل لتخطي حدود الإعلانات المكافأة في التطبيقات (Native + Flutter)
// مع تنظيف شامل لمجلدات Cache و tmp وملفات الـ Hive كل 15 ثانية

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// دالة تنفيذ المهام الدورية كل 15 ثانية (التصفير وتنظيف الملفات)
static void executePeriodicTasks(NSTimer *timer) {
    @autoreleasepool {
        NSLog(@"[AdBypass] تنفيد مهام التنظيف الدورية كل 15 ثانية...");
        
        // 1. إعادة تعيين قيم NSUserDefaults بشكل دوري
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"mvsdk_lastRewardSettingDate"];
        [defaults setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"fyb_next_allowed_session_tracking_date"];
        [defaults setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"mvsdk_lastRewardSettingDate_requestFail"];
        
        [defaults setObject:@{} forKey:@"DTX_currentUserSession"];
        [defaults setObject:@{} forKey:@"fyb_user_sessions"];
        [defaults setInteger:0 forKey:@"fyb_num_sdk_starts"];
        [defaults setInteger:0 forKey:@"fyb_num_app_version_starts"];
        [defaults setInteger:0 forKey:@"fyb_num_sdk_version_starts"];
        [defaults setInteger:0 forKey:@"kICountUpToDateKey"];
        [defaults setInteger:999999 forKey:@"mvsdk_rewardSetting_apiCap"];
        
        [defaults synchronize];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // 2. حذف ملفات Flutter / التخزين المؤقت المحددة من مجلد Documents
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSArray *filesToDelete = @[
            @"hydrated_box.hive",
            @"hydrated_box.lock",
            @"flutter_secure_storage.dat",
            @"shared_preferences.json"
        ];
        
        for (NSString *fileName in filesToDelete) {
            NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
            if ([fileManager fileExistsAtPath:filePath]) {
                NSError *error = nil;
                [fileManager removeItemAtPath:filePath error:&error];
                if (!error) {
                    NSLog(@"[AdBypass] تم حذف ملف التخزين: %@", fileName);
                }
            }
        }
        
        // 3. تفريغ مجلد الـ Cache بالكامل (Library/Caches)
        NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        if (cachesPath) {
            NSArray *cachesContents = [fileManager contentsOfDirectoryAtPath:cachesPath error:nil];
            for (NSString *item in cachesContents) {
                // استثناء مجلدات النظام الحساسة إن وجد (يمكنك إزالتها إذا أردت الحذف الأعمى)
                NSString *itemPath = [cachesPath stringByAppendingPathComponent:item];
                NSError *error = nil;
                [fileManager removeItemAtPath:itemPath error:&error];
                if (!error) {
                    NSLog(@"[AdBypass] تم مسح محتوى من Caches: %@", item);
                }
            }
        }
        
        // 4. تفريغ مجلد الـ tmp بالكامل (Temporary Directory)
        NSString *tmpPath = NSTemporaryDirectory();
        if (tmpPath) {
            NSArray *tmpContents = [fileManager contentsOfDirectoryAtPath:tmpPath error:nil];
            for (NSString *item in tmpContents) {
                NSString *itemPath = [tmpPath stringByAppendingPathComponent:item];
                NSError *error = nil;
                [fileManager removeItemAtPath:itemPath error:&error];
                if (!error) {
                    NSLog(@"[AdBypass] تم مسح ملف مؤقت من tmp: %@", item);
                }
            }
        }
    }
}


// ==========================================================
// الجزء الأول: اعتراض NSUserDefaults (للإعلانات الأصلية)
// ==========================================================

%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"mvsdk_rewardSetting"]) {
        NSMutableDictionary *newDict = [value mutableCopy];
        if (newDict[@"cap"] && [newDict[@"cap"] isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *capDict = [newDict[@"cap"] mutableCopy];
            for (NSString *capKey in capDict.allKeys) {
                capDict[capKey] = @999999;
            }
            newDict[@"cap"] = capDict;
        }
        %orig(newDict, key);
        return;
    }
    
    if ([key isEqualToString:@"mvsdk_lastRewardSettingDate"] || 
        [key isEqualToString:@"fyb_next_allowed_session_tracking_date"] ||
        [key isEqualToString:@"mvsdk_lastRewardSettingDate_requestFail"]) {
        %orig([NSDate dateWithTimeIntervalSince1970:0], key);
        return;
    }
    
    if ([key isEqualToString:@"DTX_currentUserSession"] || [key isEqualToString:@"fyb_user_sessions"]) {
        %orig(@{}, key);
        return;
    }
    
    if ([key isEqualToString:@"vungle.gdpr.date"]) {
        %orig(@0, key);
        return;
    }

    %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    if ([key hasPrefix:@"kICountUpToDateKey"]) {
        %orig(0, key);
        return;
    }
    
    if ([key isEqualToString:@"mvsdk_rewardSetting_apiCap"]) {
        %orig(999999, key);
        return;
    }
    
    if ([key isEqualToString:@"fyb_num_sdk_starts"] || 
        [key isEqualToString:@"fyb_num_app_version_starts"] ||
        [key isEqualToString:@"fyb_num_sdk_version_starts"]) {
        %orig(0, key);
        return;
    }

    %orig;
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    if ([key isEqualToString:@"MTG_kTransformed"] || 
        [key isEqualToString:@"MTGImageCachedTransformed"] ||
        [key isEqualToString:@"com.applovin.sdk.isFirstRun"]) {
        %orig(YES, key);
        return;
    }
    %orig;
}

%end


// ==========================================================
// الجزء الثاني: تشغيل المؤقت (Timer) عند تشغيل التطبيق
// ==========================================================

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // تنفيذ التنظيف فوراً عند فتح التطبيق
    executePeriodicTasks(nil);
    
    // جدولة التكرار كل 15 ثانية بشكل مستمر في الخلفية والأمام
    [[NSRunLoop mainRunLoop] performBlock:^{
        [NSTimer scheduledTimerWithTimeInterval:15.0
                                         target:[NSBlockOperation blockOperationWithBlock:^{
                                             executePeriodicTasks(nil);
                                         }]
                                       selector:@selector(main)
                                       userInfo:nil
                                        repeats:YES];
    }];
    
    return %orig;
}

%end


// ==========================================================
// الجزء الثالث: اعتراض كتابة ملفات Plist
// ==========================================================

%hook NSDictionary

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    if ([path containsString:@"Preferences"] && 
        ([path containsString:@"applovin"] || [path containsString:@"gads"] || [path containsString:@"google"])) {
        NSLog(@"[AdBypass] Plist write detected: %@", path);
    }
    
    return %orig;
}

%end
