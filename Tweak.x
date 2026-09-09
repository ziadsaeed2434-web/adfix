#import <UIKit/UIKit.h>

// دالة تنفيذ الحذف الشامل مباشرة
void executeFullResetAndExit() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    // 1. حذف مسارات الـ Group Containers ديناميكياً
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *groupContainersPath = [libraryPath stringByAppendingPathComponent:@"Group Containers"];
    
    if ([fileManager fileExistsAtPath:groupContainersPath]) {
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:groupContainersPath error:&error];
        for (NSString *item in contents) {
            if ([item hasPrefix:@"group."]) {
                NSString *fullPath = [groupContainersPath stringByAppendingPathComponent:item];
                [fileManager removeItemAtPath:fullPath error:&error];
            }
        }
    }
    
    // 2. حذف بيانات التطبيق الداخلية (Documents, Library, tmp, StoreKit)
    NSString *homeDir = NSHomeDirectory();
    NSArray *foldersToDelete = @[@"Documents", @"Library", @"tmp", @"StoreKit"];
    
    for (NSString *folder in foldersToDelete) {
        NSString *folderPath = [homeDir stringByAppendingPathComponent:folder];
        if ([fileManager fileExistsAtPath:folderPath]) {
            [fileManager removeItemAtPath:folderPath error:&error];
        }
    }
    
    // إغلاق التطبيق فوراً بعد الحذف
    exit(0);
}

// دالة لإنشاء وعرض الزر العائم على الشاشة
void addFloatingResetButton() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        // التحقق من عدم إضافة الزر مسبقاً
        if ([keyWindow viewWithTag:9999]) return;
        
        // إنشاء الزر العائم
        UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
        resetButton.frame = CGRectMake(30, 100, 110, 45);
        resetButton.tag = 9999;
        [resetButton setTitle:@"تصفير التطبيق" forState:UIControlStateNormal];
        [resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        resetButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.9]; // لون أحمر
        resetButton.layer.cornerRadius = 22.5;
        resetButton.layer.shadowColor = [UIColor blackColor].CGColor;
        resetButton.layer.shadowOffset = CGSizeMake(0, 2);
        resetButton.layer.shadowOpacity = 0.3;
        resetButton.layer.shadowRadius = 4.0;
        
        // ربط الحدث بالدالة مباشرة دون إظهار أي نافذة تنبيه
        [resetButton addTarget:nil action:@selector(resetButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:resetButton];
    });
}

// حقن الزر عند ظهور الواجهات
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    addFloatingResetButton();
}
%end

// تنفيذ الحذف وإغلاق التطبيق فور الضغط على الزر
@interface NSObject (ResetButtonHandler)
@end

@implementation NSObject (ResetButtonHandler)
- (void)resetButtonTapped:(id)sender {
    executeFullResetAndExit();
}
@end
