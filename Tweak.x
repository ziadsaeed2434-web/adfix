#import <UIKit/UIKit.h>

// دالة الحذف والخروج الفوري
static void executeDirectCleanAndExit() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homeDir = NSHomeDirectory();
    
    // 1. مسح مجلدات التطبيق الأساسية (Documents, Library, tmp)
    NSArray *directoriesToClean = @[
        [homeDir stringByAppendingPathComponent:@"Documents"],
        [homeDir stringByAppendingPathComponent:@"Library"],
        [homeDir stringByAppendingPathComponent:@"tmp"]
    ];
    
    for (NSString *dirPath in directoriesToClean) {
        if ([fileManager fileExistsAtPath:dirPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:dirPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [dirPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // 2. البحث التلقائي وحذف جميع مجلدات App Groups
    NSString *sandboxRoot = [homeDir stringByDeletingLastPathComponent];
    NSString *sharedGroupRoot = [[sandboxRoot stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    sharedGroupRoot = [sharedGroupRoot stringByAppendingPathComponent:@"Shared/AppGroup"];
    
    if ([fileManager fileExistsAtPath:sharedGroupRoot]) {
        NSArray *groups = [fileManager contentsOfDirectoryAtPath:sharedGroupRoot error:nil];
        for (NSString *group in groups) {
            NSString *groupFullPath = [sharedGroupRoot stringByAppendingPathComponent:group];
            NSArray *groupContents = [fileManager contentsOfDirectoryAtPath:groupFullPath error:nil];
            for (NSString *file in groupContents) {
                NSString *filePath = [groupFullPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:filePath error:nil];
            }
        }
    }
    
    // 3. الخروج الفوري
    exit(0);
}

// دالة إنشاء الزر وإضافته فوق واجهة التطبيق
static void addFloatingCleanButton() {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (!keyWindow) return;
    
    // منع تكرار إنشاء الزر إذا كان موجوداً مسبقاً
    if ([keyWindow viewWithTag:9999]) return;
    
    // تصميم الزر (موقع وحجم الزر على الشاشة، يمكنك تعديل الأبعاد كما تحب)
    UIButton *cleanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cleanButton.frame = CGRectMake(30, 100, 60, 60);
    cleanButton.tag = 9999;
    cleanButton.backgroundColor = [UIColor systemRedColor];
    [cleanButton setTitle:@"🧹" forState:UIControlStateNormal];
    cleanButton.titleLabel.font = [UIFont systemFontOfSize:28];
    cleanButton.layer.cornerRadius = 30;
    cleanButton.layer.shadowColor = [UIColor blackColor].CGColor;
    cleanButton.layer.shadowOffset = CGSizeMake(0, 2);
    cleanButton.layer.shadowRadius = 4;
    cleanButton.layer.shadowOpacity = 0.3;
    
    // ربط الضغط على الزر بدالة الحذف
    [cleanButton addTarget:nil action:@selector(handleCleanButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [keyWindow addSubview:cleanButton];
}

// تنفيذ الحدث عند الضغط
@interface NSObject (CleanButtonAction)
@end
@implementation NSObject (CleanButtonAction)
- (void)handleCleanButtonTapped {
    executeDirectCleanAndExit();
}
@end

// حقن الكود أول ما يشتغل التطبيق لكي تظهر الأيقونة/الزر تلقائياً
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queues ? dispatch_get_main_queue() : dispatch_get_main_queue(), ^{
        addFloatingCleanButton();
    });
}
