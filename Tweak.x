#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *currentRandomUDID = nil;
static NSUUID *currentRandomIDFA = nil;
static NSString *currentRandomUserAgent = @"";
static NSString *currentDynamicIP = @"";
static NSTimeInterval simulatedTimeOffset = 0;

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void generateRandomAtlantaCoordinates() {
    currentLat = 33.7490 + randomInRange(-0.0450, 0.0450);
    currentLon = -84.3880 + randomInRange(-0.0450, 0.0450);
}

void generateDynamicAtlantaIP() {
    NSArray *atlantaPrefixes = @[@"12.144", @"24.98", @"65.112", @"68.174", @"70.192", @"73.130", @"104.156", @"172.58"];
    NSString *selectedPrefix = atlantaPrefixes[arc4random_uniform((uint32_t)atlantaPrefixes.count)];
    
    int third = arc4random_uniform(200) + 10;
    int fourth = arc4random_uniform(240) + 5;
    
    currentDynamicIP = [NSString stringWithFormat:@"%@.%d.%d", selectedPrefix, third, fourth];
}

void generateDynamicUserAgent() {
    NSArray *iosVersions = @[@"26_0", @"26_1", @"26_2", @"26_3", @"26_4"];
    NSString *selectedVersion = iosVersions[arc4random_uniform((uint32_t)iosVersions.count)];
    
    currentRandomUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/%@ Mobile/15E148 Safari/604.1", selectedVersion, [selectedVersion stringByReplacingOccurrencesOfString:@"_" withString:@"."]];
}

void randomizeEverything() {
    currentRandomUDID = [[NSUUID UUID] UUIDString];
    currentRandomIDFA = [NSUUID UUID];
    generateRandomAtlantaCoordinates();
    generateDynamicAtlantaIP();
    generateDynamicUserAgent();
    simulatedTimeOffset += 7200.0; // تقديم الوقت ساعتين
}

// التنفيذ الفوري: حذف كافة الملفات والمجلدات وتفريغ الإعدادات مع الحفاظ على الـ Keychain بالكامل
void executeCleanWithoutKeychain() {
    randomizeEverything();
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
    }
    
    NSString *homeDirectory = NSHomeDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // مسح كافة الملفات والمجلدات (الكاش، الكوكيز، Documents، المجلدات المؤقتة، وغيرها)
    NSArray *foldersToClean = @[
        [homeDirectory stringByAppendingPathComponent:@"Library/Caches"],
        [homeDirectory stringByAppendingPathComponent:@"Documents"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Application Support"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Preferences"],
        [homeDirectory stringByAppendingPathComponent:@"tmp"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Cookies"],
        [homeDirectory stringByAppendingPathComponent:@"Library/WebKit"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Saved Application State"]
    ];
    
    for (NSString *folderPath in foldersToClean) {
        if ([fileManager fileExistsAtPath:folderPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [folderPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // إغلاق فوري للتطبيق
    exit(0);
}

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
        
        [self.resetBtn addTarget:self action:@selector(executeCleanWithoutKeychain) forControlEvents:UIControlEventTouchUpInside];
        
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
    randomizeEverything();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[MasterManager sharedInstance] setupFloatingButton];
    });
}

// تقديم الوقت ساعتين افتراضياً
%hook NSDate
+ (id)date {
    return [%orig dateByAddingTimeInterval:simulatedTimeOffset];
}
- (NSTimeInterval)timeIntervalSinceReferenceDate {
    return %orig + simulatedTimeOffset;
}
%end

// إحداثيات أتلانطا
%hook CLLocationManager
- (void)startUpdatingLocation {
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

// ترويسات الشبكة والـ IP الوهمي
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    [mutableReq setValue:currentDynamicIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:currentDynamicIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:currentDynamicIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableReq setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [mutableReq setValue:currentRandomUserAgent forHTTPHeaderField:@"User-Agent"];
    
    return %orig(mutableReq, completionHandler);
}
%end

// تغيير الهوية
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentRandomUDID];
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return currentRandomIDFA;
}
%end
