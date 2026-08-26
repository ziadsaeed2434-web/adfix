#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = @"";
static NSString *currentRandomUDID = nil;
static NSUUID *currentRandomIDFA = nil;

double randomInRange(double min, double max) {
    min = 33.7000;
    max = 33.8000;
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// دمج البادئات الناجحة مع توليد IP فريد كلياً
void initializeUniqueIP() {
    NSArray *verifiedSuccessfulPrefixes = @[@"98.207", @"75.142", @"67.180"];
    NSString *selectedPrefix = verifiedSuccessfulPrefixes[arc4random_uniform((uint32_t)verifiedSuccessfulPrefixes.count)];
    
    static unsigned long long counter = 2000;
    counter++;
    
    NSTimeInterval timeSeed = [[NSDate date] timeIntervalSince1970] * 1000;
    unsigned long long uniqueSeed = (unsigned long long)timeSeed + counter + arc4random_uniform(55555);
    
    int third = (int)(uniqueSeed % 250) + 1;
    int fourth = (int)((uniqueSeed / 250) % 250) + 1;
    
    if (third == fourth) {
        fourth = (fourth % 200) + 15;
    }
    
    sessionFakeIP = [NSString stringWithFormat:@"%@.%d.%d", selectedPrefix, third, fourth];
}

// إدارة هوية الجهاز (UDID & IDFA) وثباتها خلال الجلسة
void initializeDeviceIdentity() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedUDID = [defaults stringForKey:@"MasterSpoofedUDID"];
    NSString *savedIDFAstr = [defaults stringForKey:@"MasterSpoofedIDFA"];
    
    if (!savedUDID || !savedIDFAstr) {
        currentRandomUDID = [[NSUUID UUID] UUIDString];
        currentRandomIDFA = [NSUUID UUID];
        
        [defaults setObject:currentRandomUDID forKey:@"MasterSpoofedUDID"];
        [defaults setObject:[currentRandomIDFA UUIDString] forKey:@"MasterSpoofedIDFA"];
        [defaults synchronize];
    } else {
        currentRandomUDID = savedUDID;
        currentRandomIDFA = [[NSUUID alloc] initWithUUIDString:savedIDFAstr];
    }
}

// الوظيفة الشاملة والفورية عند الضغط على الزر (بدون تأكيد، حذف كل شيء ما عدا Keychain)
void executeInstantMasterReset() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 1. توليد هوية جديدة كلياً
    NSString *newUDID = [[NSUUID UUID] UUIDString];
    NSUUID *newIDFA = [NSUUID UUID];
    
    [defaults setObject:newUDID forKey:@"MasterSpoofedUDID"];
    [defaults setObject:[newIDFA UUIDString] forKey:@"MasterSpoofedIDFA"];
    [defaults synchronize];
    
    // 2. مسح شامل لكل ملفات ومجلدات التطبيق (Caches, Documents, Library, tmp) واستثناء Keychain
    NSString *homeDirectory = NSHomeDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *foldersToClean = @[
        [homeDirectory stringByAppendingPathComponent:@"Library/Caches"],
        [homeDirectory stringByAppendingPathComponent:@"Documents"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Application Support"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Preferences"],
        [homeDirectory stringByAppendingPathComponent:@"tmp"]
    ];
    
    for (NSString *folderPath in foldersToClean) {
        if ([fileManager fileExistsAtPath:folderPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
            for (NSString *file in contents) {
                // استثناء ملفات إعدادات التويك أو النظام الخاصة بنا إذا لزم الأمر، أو حذف الكل
                NSString *fullPath = [folderPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // 3. إغلاق التطبيق فوراً وبدون أي انتظار
    exit(0);
}

// الواجهة العائمة والزر المتحرك
@interface MasterWindow : UIWindow
@end

@implementation MasterWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:777888];
    if (btn && CGRectContainsPoint(btn.frame, point)) {
        return YES;
    }
    return NO;
}
@end

@interface MasterManager : NSObject
@property (strong, nonatomic) MasterWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation MasterManager

+ (instancetype)sharedInstance {
    static MasterManager *sharedInstance = nil;
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
        self.floatingWindow = [[MasterWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 3000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        // زر أحمر مميز مكتوب عليه RESET
        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 777888;
        self.resetBtn.frame = CGRectMake(20, 180, 65, 65);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.9];
        [self.resetBtn setTitle:@"RESET" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.resetBtn.layer.cornerRadius = 32.5;
        self.resetBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.resetBtn.layer.shadowOffset = CGSizeMake(0, 3);
        self.resetBtn.layer.shadowOpacity = 0.6;
        self.resetBtn.layer.shadowRadius = 5;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan];
        
        // تنفيذ عملية الحذف والخروج الفوري بدون إظهار أي قائمة تأكيد
        [self.resetBtn addTarget:self action:@selector(executeInstantMasterReset) forControlEvents:UIControlEventTouchUpInside];
        
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

@end

%ctor {
    updateAtlantaLocation();
    initializeUniqueIP();
    initializeDeviceIdentity();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[MasterManager sharedInstance] setupFloatingButton];
    });
}

// خطاف الموقع الجغرافي (أتلانطا)
%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

// خطاف الشبكة لحقن الـ IP الأمريكي الفريد وترويسات المتصفح
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    
    [mutableReq setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [mutableReq setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
    
    return %orig(mutableReq, completionHandler);
}
%end

// خطاف المعرفات لتغيير UDID
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentRandomUDID) {
        initializeDeviceIdentity();
    }
    return [[NSUUID alloc] initWithUUIDString:currentRandomUDID];
}
%end

// خطاف المعرفات لتغيير IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!currentRandomIDFA) {
        initializeDeviceIdentity();
    }
    return currentRandomIDFA;
}
%end
