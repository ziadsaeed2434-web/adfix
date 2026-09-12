#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // جلب مسار مجلد المكتبة الخاص بالتطبيق
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 1. مسح ملفات تفضيلات الإعلانات والتتبع المؤقتة (مثل AdSupport و gads) من Preferences
    NSString *prefsPath = [libraryDirectory stringByAppendingPathComponent:@"Preferences"];
    NSArray *prefsFilesToDelete = @[@"__gads__.plist", @"com.apple.AdSupport.plist"];
    for (NSString *file in prefsFilesToDelete) {
        NSString *filePath = [prefsPath stringByAppendingPathComponent:file];
        if ([fileManager fileExistsAtPath:filePath]) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
    
    // 2. مسح كاش ومحتويات مجلد GoogleMobileAds داخل Application Support لتصفير حالة الإعلانات
    NSString *appSupportPath = [libraryDirectory stringByAppendingPathComponent:@"Application Support"];
    NSString *gadsSupportPath = [appSupportPath stringByAppendingPathComponent:@"GoogleMobileAds"];
    if ([fileManager fileExistsAtPath:gadsSupportPath]) {
        [fileManager removeItemAtPath:gadsSupportPath error:nil];
    }
    
    // 3. تصفير مفاتيح NSUserDefaults المرتبطة بالتثبيت ومعرفات الجهاز
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"device.id.key"];
    [defaults removeObjectForKey:@"AppsFlyerInstallDate"];
    [defaults removeObjectForKey:@"AppsFlyerReinstallCounter"];
    [defaults synchronize];
    
    return %orig;
}

%end

// اعتراض قراءة معرف الجهاز لإعطاء معرف جديد وهمي مع كل طلب إعلان
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"device.id.key"]) {
        return [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"AppsFlyerReinstallCounter"]) {
        return 0;
    }
    return %orig;
}

%end
