#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

static NSString *currentIDFV = nil;
static NSString *currentIDFA = nil;

// دالة توليد UUID آمنة ومستقرة تماماً
static NSString *generateNewUUID() {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    if (!uuid) return [[NSUUID UUID] UUIDString];
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    if (!string) return [[NSUUID UUID] UUIDString];
    
    NSString *result = [NSString stringWithString:(__bridge NSString *)string];
    CFRelease(string);
    return result;
}

// دالة تنظيف الملفات بشكل آمن مع حماية ضد الأخطاء
static void clearAllIdentifiersAndFirebase() {
    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        // التصحيح هنا: استبدال القوس المربع بقوس دبريلي أو نقطة صحيحة
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        if ([paths count] == 0) return;
        NSString *libraryPath = paths[0];
        
        NSArray *pathsToClean = @[
            [libraryPath stringByAppendingPathComponent:@"Caches/com.google.firebase.installations"],
            [libraryPath stringByAppendingPathComponent:@"Application Support/Firebase/Installations"]
        ];
        
        for (NSString *path in pathsToClean) {
            if ([fileManager fileExistsAtPath:path]) {
                [fileManager removeItemAtPath:path error:nil];
            }
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dict = [defaults dictionaryRepresentation];
        for (NSString *key in dict.allKeys) {
            if ([key rangeOfString:@"FIR" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [key rangeOfString:@"firebase" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [key rangeOfString:@"installations" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [defaults removeObjectForKey:key];
            }
        }
        [defaults synchronize];
    } @catch (NSException *exception) {
        // تجاهل أي خطأ مفاجئ لكي لا يكرش التطبيق
    }
}

// 1. خطاف معرف الجهاز
%hook UIDevice
- (NSUUID *)identifierForVendor {
    @try {
        if (!currentIDFV) {
            currentIDFV = generateNewUUID();
        }
        return [[NSUUID alloc] initWithUUIDString:currentIDFV];
    } @catch (NSException *e) {
        return %orig;
    }
}
%end

// 2. خطاف معرف الإعلانات
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        if (!currentIDFA) {
            currentIDFA = generateNewUUID();
        }
        return [[NSUUID alloc] initWithUUIDString:currentIDFA];
    } @catch (NSException *e) {
        return %orig;
    }
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// 3. خطاف دورة الحياة مع حماية شاملة من الـ Crash
%hook AppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    currentIDFV = nil;
    currentIDFA = nil;
    clearAllIdentifiersAndFirebase();
}

%end
