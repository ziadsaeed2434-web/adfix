#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// 1. تعريف المتغيرات الثابتة للجلسة الحالية
static NSString *currentIDFV = nil;
static NSString *currentIDFA = nil;

// دالة مساعدة لتوليد UUID متوافقة مع جميع بيئات التجميع (بدون أخطاء ARC)
static NSString *generateNewUUID() {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    NSString *result = [NSString stringWithString:(__bridge NSString *)string];
    CFRelease(string);
    CFRelease(uuid);
    return result;
}

// 2. دالة تنظيف ملفات الـ FID والفايربيز والتخزين المؤقت بالترتيب الصحيح
static void clearAllIdentifiersAndFirebase() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    
    // أ) مسح مجلدات الكاش الخاصة بـ Firebase Installations والـ FID
    NSArray *pathsToClean = @[
        [libraryPath stringByAppendingPathComponent:@"Caches/com.google.firebase.installations"],
        [libraryPath stringByAppendingPathComponent:@"Application Support/Firebase/Installations"]
    ];
    
    for (NSString *path in pathsToClean) {
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
        }
    }
    
    // ب) تنظيف الـ NSUserDefaults من مفاتيح الفايربيز المرتبطة بمعرف التثبيت
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    for (NSString *key in dict.allKeys) {
        if ([key containsString:@"FIR"] || [key containsString:@"firebase"] || [key containsString:@"gcm"] || [key containsString:@"installations"]) {
            [defaults removeObjectForKey:key];
        }
    }
    [defaults synchronize];
}

// 3. خطاف الـ UDID / IDFV
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentIDFV) {
        currentIDFV = generateNewUUID();
    }
    return [[NSUUID alloc] initWithUUIDString:currentIDFV];
}
%end

// 4. خطاف الـ IDFA (معرف الإعلانات)
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!currentIDFA) {
        currentIDFA = generateNewUUID();
    }
    return [[NSUUID alloc] initWithUUIDString:currentIDFA];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// 5. خطاف إدارة دورة حياة التطبيق (AppDelegate) للتصفير عند الخروج
%hook AppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    
    // أولاً: تفريغ المعرفات لكي تتولد هويات جديدة في المرة القادمة
    currentIDFV = nil;
    currentIDFA = nil;
    
    // ثانياً: مسح ملفات ومفاتيح الـ FID والفايربيز
    clearAllIdentifiersAndFirebase();
}

%end
