#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>

static NSString *kCurrentIPKey = @"com.atlantic.spoof.currentip";
static NSString *kRequestLogKey = @"com.atlantic.spoof.requests";
static NSString *kLastLaunchKey = @"com.atlantic.spoof.lastlaunch";

@interface UIWindow (Private)
- (void)_setSecure:(BOOL)secure;
@end

@interface AtlanticIPManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)generateRandomIP;
- (NSString *)currentIP;
- (void)logRequest:(NSString *)url;
- (NSArray<NSString *> *)requestLog;
- (void)refreshIPForNewLaunch;
@end

@implementation AtlanticIPManager {
    NSString *_currentIP;
    NSMutableArray<NSString *> *_requestLog;
}

+ (instancetype)sharedManager {
    static AtlanticIPManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AtlanticIPManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestLog = [NSMutableArray array];
        [self refreshIPForNewLaunch];
    }
    return self;
}

- (NSString *)generateRandomIP {
    // النطاق 1: 172.57.x.x / النطاق 2: 172.59.x.x
    int secondOctet = (arc4random() % 2 == 0) ? 57 : 59;
    int thirdOctet = arc4random() % 256;
    int fourthOctet = arc4random() % 256;
    return [NSString stringWithFormat:@"172.%d.%d.%d", secondOctet, thirdOctet, fourthOctet];
}

- (void)refreshIPForNewLaunch {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *lastLaunch = [defaults objectForKey:kLastLaunchKey];
    NSDate *now = [NSDate date];
    
    // إذا كان التطبيق مغلق تمامًا (cold start) نولد IP جديد
    if (!lastLaunch || [now timeIntervalSinceDate:lastLaunch] > 2.0) {
        _currentIP = [self generateRandomIP];
        [_requestLog removeAllObjects];
        [defaults setObject:_currentIP forKey:kCurrentIPKey];
        [defaults setObject:now forKey:kLastLaunchKey];
        [defaults synchronize];
    } else {
        _currentIP = [defaults stringForKey:kCurrentIPKey] ?: [self generateRandomIP];
    }
}

- (NSString *)currentIP {
    return _currentIP;
}

- (void)logRequest:(NSString *)url {
    if (url.length > 0) {
        NSString *entry = [NSString stringWithFormat:@"[%@] → %@", _currentIP, url];
        [_requestLog addObject:entry];
        if (_requestLog.count > 100) [_requestLog removeObjectAtIndex:0];
    }
}

- (NSArray<NSString *> *)requestLog {
    return [_requestLog copy];
}

@end

// ============================================
// HOOK: NSURLSession - اعتراض الطلبات
// ============================================

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    [[AtlanticIPManager sharedManager] logRequest:request.URL.absoluteString];
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    [[AtlanticIPManager sharedManager] logRequest:url.absoluteString];
    return %orig;
}

%end

// ============================================
// HOOK: NSURLConnection (للتطبيقات القديمة)
// ============================================

%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    [[AtlanticIPManager sharedManager] logRequest:request.URL.absoluteString];
    return %orig;
}

%end

// ============================================
// الزر العائم الثابت (Floating Button)
// ============================================

@interface AtlanticFloatingButton : UIButton
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, assign) BOOL isPanelVisible;
@end

@implementation AtlanticFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:0.85];
        self.layer.cornerRadius = 25;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 4;
        
        [self setTitle:@"IP" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        
        // Pan gesture للسحب
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        [self addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
        
        [self setupPanel];
    }
    return self;
}

- (void)setupPanel {
    _panelView = [[UIView alloc] initWithFrame:CGRectMake(-200, 60, 220, 300)];
    _panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    _panelView.layer.cornerRadius = 12;
    _panelView.layer.borderColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0].CGColor;
    _panelView.layer.borderWidth = 1.5;
    _panelView.hidden = YES;
    [self addSubview:_panelView];
    
    _infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 40)];
    _infoLabel.textColor = [UIColor whiteColor];
    _infoLabel.font = [UIFont boldSystemFontOfSize:13];
    _infoLabel.numberOfLines = 2;
    _infoLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_infoLabel];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(10, 55, 200, 20)];
    header.text = @"سجل الطلبات:";
    header.textColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0];
    header.font = [UIFont boldSystemFontOfSize:12];
    header.textAlignment = NSTextAlignmentRight;
    [_panelView addSubview:header];
    
    _logView = [[UITextView alloc] initWithFrame:CGRectMake(5, 80, 210, 210)];
    _logView.backgroundColor = [UIColor clearColor];
    _logView.textColor = [UIColor greenColor];
    _logView.font = [UIFont fontWithName:@"Courier" size:10];
    _logView.editable = NO;
    _logView.textAlignment = NSTextAlignmentRight;
    [_panelView addSubview:_logView];
}

- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    _panelView.hidden = !_isPanelVisible;
    
    if (_isPanelVisible) {
        [self updateInfo];
        [self startLogTimer];
    } else {
        [self stopLogTimer];
    }
}

- (void)updateInfo {
    AtlanticIPManager *manager = [AtlanticIPManager sharedManager];
    _infoLabel.text = [NSString stringWithFormat:@"IP الحالي:\n%@", manager.currentIP];
    
    NSArray *logs = [manager requestLog];
    _logView.text = logs.count > 0 ? [logs componentsJoinedByString:@"\n"] : @"لا توجد طلبات بعد";
    
    // التمرير للأسفل
    if (_logView.text.length > 0) {
        NSRange bottom = NSMakeRange(_logView.text.length - 1, 1);
        [_logView scrollRangeToVisible:bottom];
    }
}

- (void)startLogTimer {
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        if (!self.isPanelVisible) {
            [timer invalidate];
            return;
        }
        [self updateInfo];
    }];
}

- (void)stopLogTimer {
    // يتم إيقافه تلقائيًا عند إخفاء اللوحة
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    
    // حدود الشاشة
    CGFloat margin = 25;
    center.x = MAX(margin, MIN(self.superview.bounds.size.width - margin, center.x));
    center.y = MAX(margin + 20, MIN(self.superview.bounds.size.height - margin, center.y));
    
    self.center = center;
    [gesture setTranslation:CGPointZero inView:self.superview];
}

@end

// ============================================
// إضافة الزر فوق كل شيء عبر UIWindow
// ============================================

static AtlanticFloatingButton *gFloatingButton = nil;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [self setupFloatingButtonIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    [self setupFloatingButtonIfNeeded];
}

%new
- (void)setupFloatingButtonIfNeeded {
    if (gFloatingButton && gFloatingButton.superview == self) return;
    
    if (!gFloatingButton) {
        gFloatingButton = [[AtlanticFloatingButton alloc] initWithFrame:CGRectMake(
            self.bounds.size.width - 70, 
            self.bounds.size.height / 2 - 25, 
            50, 50
        )];
    }
    
    if (!gFloatingButton.superview) {
        [self addSubview:gFloatingButton];
    }
    
    // ضمان البقاء في المقدمة
    [self bringSubviewToFront:gFloatingButton];
}

%end

// ============================================
// Hook AppDelegate لضمان تغيير IP عند Launch
// ============================================

%hook UIApplication

- (void)_run {
    [[AtlanticIPManager sharedManager] refreshIPForNewLaunch];
    %orig;
}

%end

// ============================================
// تغيير موقع الجهاز (Location Spoofing)
// ============================================

@interface CLLocation (Spoof)
@end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    // توليد إحداثيات تطابق نطاق IP أمريكا أطلنطا (منطقة فيرجينيا/نيويورك تقريبًا)
    // 172.57.x.x ≈ منطقة نيويورك / فيرجينيا
    // 172.59.x.x ≈ منطقة نيويورك / نيوجيرسي
    CLLocationCoordinate2D coord;
    coord.latitude = 40.7128 + ((arc4random() % 1000) / 10000.0);  // ~نيويورك
    coord.longitude = -74.0060 + ((arc4random() % 1000) / 10000.0);
    return coord;
}

- (CLLocationDistance)altitude {
    return 10.0;
}

- (CLLocationAccuracy)horizontalAccuracy {
    return 5.0;
}

- (CLLocationAccuracy)verticalAccuracy {
    return 5.0;
}

%end

%ctor {
    NSLog(@"[AtlanticIPSpoofer] تم تحميل التويك");
}
