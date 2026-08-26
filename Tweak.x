#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

// متغيرات لتخزين معرفات الجلسة الحالية
static NSString *currentRandomUDID = nil;
static NSUUID *currentRandomIDFA = nil;

// دالة توليد UDID عشوائي جديد
NSString* generateRandomUDIDString() {
    return [[NSUUID UUID] UUIDString];
}

// دالة توليد IDFA عشوائي جديد
NSUUID* generateRandomIDFAUUID() {
    return [NSUUID UUID];
}

// تهيئة الهوية الجديدة وتخزينها في UserDefaults لضمان ثباتها طوال الجلسة الحالية حتى يتم الضغط على الزر
void initializeNewDeviceIdentity() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedUDID = [defaults stringForKey:@"CustomSpoofedUDID"];
    NSString *savedIDFAstr = [defaults stringForKey:@"CustomSpoofedIDFA"];
    
    if (!savedUDID || !savedIDFAstr) {
        currentRandomUDID = generateRandomUDIDString();
        currentRandomIDFA = generateRandomIDFAUUID();
        
        [defaults setObject:currentRandomUDID forKey:@"CustomSpoofedUDID"];
        [defaults setObject:[currentRandomIDFA UUIDString] forKey:@"CustomSpoofedIDFA"];
        [defaults synchronize];
    } else {
        currentRandomUDID = savedUDID;
        currentRandomIDFA = [[NSUUID alloc] initWithUUIDString:savedIDFAstr];
    }
}

// دالة تنظيف وحذف بيانات التطبيق (Cache & Documents)
void clearAppDataAndResetIdentity() {
    // 1. توليد هوية جديدة وحفظها
    currentRandomUDID = generateRandomUDIDString();
    currentRandomIDFA = generateRandomIDFAUUID();
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:currentRandomUDID forKey:@"CustomSpoofedUDID"];
    [defaults setObject:[currentRandomIDFA UUIDString] forKey:@"CustomSpoofedIDFA"];
    [defaults synchronize];
    
    // 2. مسح الكاش وملفات المستندات المؤقتة الخاصة بالتطبيق
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cachesDirectory error:&error];
    for (NSString *file in cacheFiles) {
        NSString *filePath = [cachesDirectory stringByAppendingPathComponent:file];
        [fileManager removeItemAtPath:filePath error:nil];
    }
    
    // مسح مجلد Documents أيضاً إن وجد لتنظيف البيانات تماماً
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDirectory = [docPaths objectAtIndex:0];
    NSArray *docFiles = [fileManager contentsOfDirectoryAtPath:docDirectory error:&error];
    for (NSString *file in docFiles) {
        NSString *filePath = [docDirectory stringByAppendingPathComponent:file];
        [fileManager removeItemAtPath:filePath error:nil];
    }
    
    NSLog(@"[ResetTweak] تم تغيير المعرفات وحذف بيانات التطبيق بنجاح.");
    
    // 3. إنهاء التطبيق تماماً لإعادة التشغيل بهوية جديدة نظيفة
    exit(0);
}

// نافذة الزر العائم لكي يظهر فوق كل الشاشات
@interface ResetWindow : UIWindow
@end

@implementation ResetWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:888999];
    if (btn && CGRectContainsPoint(btn.frame, point)) {
        return YES;
    }
    return NO;
}
@end

@interface ResetManager : NSObject
@property (strong, nonatomic) ResetWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation ResetManager

+ (instancetype)sharedInstance {
    static ResetManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.floatingWindow = [[ResetWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 2000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        // تصميم الزر (مكتوب عليه RESET بلون مميز لسهولة الاستخدام)
        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 888999;
        self.resetBtn.frame = CGRectMake(20, 200, 65, 65);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.9]; // لون أحمر تحذيري للريست
        [self.resetBtn setTitle:@"RESET" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.resetBtn.layer.cornerRadius = 32.5;
        self.resetBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.resetBtn.layer.shadowOffset = CGSizeMake(0, 3);
        self.resetBtn.layer.shadowOpacity = 0.6;
        self.resetBtn.layer.shadowRadius = 5;
        
        // إمكانية سحب وتحريك الزر في أي مكان بالشاشة
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan];
        
        // تنفيذ عملية الحذف والتغيير عند الضغط على الزر
        [self.resetBtn addTarget:self action:@selector(executeResetAction) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.resetBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer * _Nonnull)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    
    CGFloat newX = btn.center.x + translation.x;
    CGFloat newY = btn.center.y + translation.y;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newX = MAX(35, MIN(screenSize.width - 35, newX));
    newY = MAX(45, MIN(screenSize.height - 45, newY));
    
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}

- (void)executeResetAction {
    // إظهار تنبيه بسيط قبل التنفيذ الإجباري
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة ضبط الهوية" message:@"سيتم تغيير UDID و IDFA، حذف الكاش، وإعادة تشغيل التطبيق فوراً. هل أنت متأكد؟" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"نعم، نفذ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        clearAppDataAndResetIdentity();
    }]];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

@end

%ctor {
    initializeNewDeviceIdentity();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ResetManager sharedInstance] setupFloatingButton];
    });
}

// اعتراض UDID وإرجاع القيمة الوهمية الحالية
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentRandomUDID) {
        initializeNewDeviceIdentity();
    }
    return [[NSUUID alloc] initWithUUIDString:currentRandomUDID];
}
%end

// اعتراض IDFA وإرجاع القيمة الوهمية الحالية
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!currentRandomIDFA) {
        initializeNewDeviceIdentity();
    }
    return currentRandomIDFA;
}
%end
