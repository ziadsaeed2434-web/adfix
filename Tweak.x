#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>

// ---------------------------------------------------------------------------
// MARK: - Global Spoofing State
// ---------------------------------------------------------------------------

static NSString *g_spoofedName = nil;
static NSString *g_spoofedSystemVersion = nil;
static NSUUID *g_spoofedIDFA = nil;
static float g_spoofedBatteryLevel = 0.0;
static UIDeviceBatteryState g_spoofedBatteryState = UIDeviceBatteryStateUnknown;
static NSString *g_spoofedUserAgent = nil;

// Network & Geo Spoofing State
static NSString *g_currentSpoofedIP = nil;
static double g_spoofedLatitude = 37.7749;
static double g_spoofedLongitude = -122.4194;
static BOOL g_hasSpoofed = NO;

// ---------------------------------------------------------------------------
// MARK: - Helper Functions (IP, Geo, User-Agent & Randomizers)
// ---------------------------------------------------------------------------

static float randomFloatBetween(float min, float max) {
    return ((float)arc4random() / (float)UINT32_MAX) * (max - min) + min;
}

// توليد آيبي عشوائي ضمن نطاقات T-Mobile (172.56.0.0 إلى 172.63.0.0)
static NSString *generateTMobileIP(void) {
    int secondOctet = 56 + arc4random_uniform(8);
    int thirdOctet = arc4random_uniform(254) + 1;
    int fourthOctet = arc4random_uniform(254) + 1;
    return [NSString stringWithFormat:@"172.%d.%d.%d", secondOctet, thirdOctet, fourthOctet];
}

// التحقق من أن الآيبي سكنى وتابع لـ T-Mobile (AS21928)
static BOOL verifyResidentialIP(NSString *ipString) {
    NSString *urlString = [NSString stringWithFormat:@"http://ip-api.com/json/%@", ipString];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:3.0];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL isValid = NO;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            @try {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json && [json[@"status"] isEqualToString:@"success"]) {
                    NSString *org = json[@"org"];
                    NSString *asStr = json[@"as"];
                    if ([org localizedCaseInsensitiveContainsString:@"T-Mobile"] || 
                        [asStr localizedCaseInsensitiveContainsString:@"AS21928"]) {
                        isValid = YES;
                        g_spoofedLatitude = [json[@"lat"] doubleValue];
                        g_spoofedLongitude = [json[@"lon"] doubleValue];
                    }
                }
            } @catch (NSException *e) {} // تم تصحيح الخطأ هنا
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 3.5 * NSEC_PER_SEC));
    return isValid;
}

static void fetchAndVerifyValidIP(void) {
    int attempts = 0;
    while (attempts < 5) {
        NSString *candidateIP = generateTMobileIP();
        if (verifyResidentialIP(candidateIP)) {
            g_currentSpoofedIP = candidateIP;
            return;
        }
        attempts++;
    }
    g_currentSpoofedIP = [NSString stringWithFormat:@"172.%d.%d.%d", 56 + arc4random_uniform(8), arc4random_uniform(250)+1, arc4random_uniform(250)+1];
    g_spoofedLatitude = 37.3861 + randomFloatBetween(-1.0, 1.0);
    g_spoofedLongitude = -122.0839 + randomFloatBetween(-1.0, 1.0);
}

static NSString *randomDeviceName(void) {
    NSArray *names = @[@"iPhone", @"iPhone Pro", @"iPhone Max"];
    NSString *base = names[arc4random_uniform((uint32_t)names.count)];
    int model = arc4random_uniform(20) + 1;
    return [NSString stringWithFormat:@"%@ %d", base, model];
}

static NSString *randomSystemVersion(void) {
    int major = 24 + arc4random_uniform(4);
    int minor = arc4random_uniform(10);
    int patch = arc4random_uniform(10);
    return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
}

// توليد User-Agent واقعي ودقيق متوافق مع نظام التشغيل المتغير
static NSString *randomUserAgent(NSString *systemVersion) {
    NSArray *components = [systemVersion componentsSeparatedByString:@"."];
    NSString *major = components.count > 0 ? components[0] : @"26";
    NSString *minor = components.count > 1 ? components[1] : @"0";
    int buildNumber = arc4random_uniform(900) + 100;
    
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (iPhone; CPU iPhone OS %@_%@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/%@ Mobile/15E%d Safari/604.1",
            major, minor, major, buildNumber];
}

// ---------------------------------------------------------------------------
// MARK: - Floating Button Implementation
// ---------------------------------------------------------------------------

@interface ResetFloatingButton : UIButton
@property (nonatomic, assign) CGPoint initialCenter;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation ResetFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        self.layer.cornerRadius = 25.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.titleLabel.font = [UIFont systemFontOfSize:24.0];
        [self setTitle:@"⟳" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self addTarget:self action:@selector(handleTap:) forControlEvents:UIControlEventTouchUpInside];

        self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:self.panGesture];
    }
    return self;
}

- (void)handleTap:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performReset];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            exit(0);
        });
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    if (!superview) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.initialCenter = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:superview];
        self.center = CGPointMake(self.initialCenter.x + translation.x,
                                  self.initialCenter.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled) {
        CGRect bounds = superview.bounds;
        CGFloat margin = 10.0;
        CGFloat halfWidth = self.frame.size.width / 2.0;
        CGFloat halfHeight = self.frame.size.height / 2.0;
        CGFloat newX = MIN(MAX(self.center.x, margin + halfWidth), bounds.size.width - margin - halfWidth);
        CGFloat newY = MIN(MAX(self.center.y, margin + halfHeight), bounds.size.height - margin - halfHeight);
        [UIView animateWithDuration:0.2 animations:^{
            self.center = CGPointMake(newX, newY);
        }];
        self.initialCenter = self.center;
    }
}

- (void)performReset {
    @try {
        // 1. توليد بيانات الجهاز والـ User-Agent الجديد
        g_spoofedName = randomDeviceName();
        g_spoofedSystemVersion = randomSystemVersion();
        g_spoofedIDFA = [NSUUID UUID]; 
        g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
        g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
        
        // توليد User-Agent متناسق تماماً مع إصدار النظام الجديد
        g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
        
        // 2. جلب آيبي سكني وتحديث الإحداثيات
        fetchAndVerifyValidIP();
        
        g_hasSpoofed = YES;

        // 3. مسح جميع ملفات ومجلدات التطبيق وكاش الشبكة والكوكيز بالكامل (مع استثناء NSUserDefaults)
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        NSArray *foldersToClean = @[@"Documents", @"Library", @"tmp", @"Caches"];
        
        for (NSString *folder in foldersToClean) {
            NSString *folderPath = [homeDir stringByAppendingPathComponent:folder];
            if ([fm fileExistsAtPath:folderPath]) {
                NSArray *contents = [fm contentsOfDirectoryAtPath:folderPath error:nil];
                for (NSString *item in contents) {
                    if ([folder isEqualToString:@"Library"] && [item isEqualToString:@"Preferences"]) {
                        continue; // استثناء مجلد التفضيلات لحماية NSUserDefaults
                    }
                    NSString *fullPath = [folderPath stringByAppendingPathComponent:item];
                    [fm removeItemAtPath:fullPath error:nil];
                }
            }
        }

        // مسح الكوكيز والكاش
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
    } @catch (NSException *exception) {}
}

@end

// ---------------------------------------------------------------------------
// MARK: - Hooking UIDevice & IDFA
// ---------------------------------------------------------------------------

%hook UIDevice

- (NSString *)name {
    if (g_hasSpoofed && g_spoofedName) return g_spoofedName;
    return %orig;
}

- (NSString *)systemVersion {
    if (g_hasSpoofed && g_spoofedSystemVersion) return g_spoofedSystemVersion;
    return %orig;
}

- (float)batteryLevel {
    if (g_hasSpoofed) return g_spoofedBatteryLevel;
    return %orig;
}

- (UIDeviceBatteryState)batteryState {
    if (g_hasSpoofed) return g_spoofedBatteryState;
    return %orig;
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if (g_hasSpoofed && g_spoofedIDFA) {
        return g_spoofedIDFA;
    }
    return %orig;
}

%end

// ---------------------------------------------------------------------------
// MARK: - Hooking CoreLocation
// ---------------------------------------------------------------------------

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (g_hasSpoofed) {
        return CLLocationCoordinate2DMake(g_spoofedLatitude, g_spoofedLongitude);
    }
    return %orig;
}

%end

%hook CLLocationManager

- (CLLocation *)location {
    if (g_hasSpoofed) {
        return [[CLLocation alloc] initWithLatitude:g_spoofedLatitude longitude:g_spoofedLongitude];
    }
    return %orig;
}

%end

// ---------------------------------------------------------------------------
// MARK: - Hooking NSURLSession (User-Agent & IP Injection)
// ---------------------------------------------------------------------------

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    if (g_hasSpoofed) {
        if (g_spoofedUserAgent) {
            [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        if (g_currentSpoofedIP) {
            [mutableRequest setValue:g_currentSpoofedIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableRequest setValue:g_currentSpoofedIP forHTTPHeaderField:@"Client-IP"];
        }
    }
    [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
    return %orig(mutableRequest);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    if (g_hasSpoofed) {
        if (g_spoofedUserAgent) {
            [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        if (g_currentSpoofedIP) {
            [mutableRequest setValue:g_currentSpoofedIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableRequest setValue:g_currentSpoofedIP forHTTPHeaderField:@"Client-IP"];
        }
    }
    [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
    return %orig(mutableRequest, completionHandler);
}

%end

// ---------------------------------------------------------------------------
// MARK: - Adding the Floating Button
// ---------------------------------------------------------------------------

static ResetFloatingButton *g_floatingButton = nil;
static BOOL g_buttonAdded = NO;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    if (!g_buttonAdded && self.isKeyWindow) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CGFloat screenWidth = self.bounds.size.width;
                CGFloat buttonWidth = 50.0;
                CGFloat buttonHeight = 50.0;
                CGFloat rightX = screenWidth - buttonWidth - 20.0;
                CGFloat topY = 100.0;

                g_floatingButton = [[ResetFloatingButton alloc] initWithFrame:CGRectMake(rightX, topY, buttonWidth, buttonHeight)];
                [self addSubview:g_floatingButton];
                g_buttonAdded = YES;
            });
        }
    }
}

%end

// ---------------------------------------------------------------------------
// MARK: - Constructor
// ---------------------------------------------------------------------------

%ctor {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return;
    }
    %init;
}
