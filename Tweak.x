#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

void wipeAppDataOnly() {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleID) return;
        
        // 1. مسح وتفريغ كافة الـ UserDefaults الخاصة بالتطبيق
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 2. مسح ملف الـ Plist الخاص بإعدادات التخزين المؤقت من جذوره
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDir = [paths firstObject];
        NSString *prefsDir = [libraryDir stringByAppendingPathComponent:@"Preferences"];
        NSString *plistFilePath = [prefsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:plistFilePath]) {
            [fileManager removeItemAtPath:plistFilePath error:nil];
        }
    }
}

// تنفيذ عملية الحذف والتنظيف الشاملة فور فتح التطبيق في كل مرة
%ctor {
    wipeAppDataOnly();
}
