#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>
#import <objc/runtime.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";
static UIWindow *floatingWindow = nil;

// دوال توليد وجلب الهوية الحالية
static NSString *getDynamicIP() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedIP = [defaults stringForKey:@"MySpoofedIPSession"];
        
        if (!savedIP) {
            int third = arc4random_uniform(200) + 1;
            int fourth = arc4random_uniform(250) + 1;
            savedIP = [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
            [defaults setObject:savedIP forKey:@"MySpoofedIPSession"];
            [defaults synchronize];
        }
        return savedIP;
    } @catch (NSException *e) {
        return @"50.200.50.50";
    }
}

static NSString *getDynamicIDFA() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedIDFA = [defaults stringForKey:@"MySpoofedIDFASession"];
        
        if (!savedIDFA) {
            savedIDFA = [[NSUUID UUID] UUIDString];
            [defaults setObject:savedIDFA forKey:@"MySpoofedIDFASession"];
            [defaults synchronize];
        }
        return savedIDFA;
    } @catch (NSException *e) {
        return [[NSUUID UUID] UUIDString];
    }
}

// دالة تغيير الآبي والـ IDFA فوراً عند الضغط على الزر
static void rotateIdentityNow() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"MySpoofedIPSession"];
        [defaults removeObjectForKey:@"MySpoofedIDFASession"];
        [defaults synchronize];
        
        getDynamicIP();
        getDynamicIDFA();
        
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
        
        // تأثير اهتزاز خفيف مؤكد للضغط (Haptic Feedback)
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator impactOccurred];
    } @catch (NSException *e) {}
}

// كلاس خاص بالزر العائم القابل للسحب
@interface SpoofFloatingButton : UIButton
@end

@implementation SpoofFloatingButton {
    CGPoint touchLocation;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    touchLocation = [touch locationInView:self.superview];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    
    // تحريك الزر بإصبعك إلى أي مكان تختاره في الشاشة
    CGFloat deltaX = currentLocation.x - touchLocation.x;
    CGFloat deltaY = currentLocation.y - touchLocation.y;
    
    CGPoint newCenter = CGPointMake(self.center.x + deltaX, self.center.y + deltaY);
    
    // منع خروج الزر عن حدود الشاشة
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newCenter.x = MAX(self.frame.size.width/2, MIN(screenSize.width - self.frame.size.width/2, newCenter.x));
    newCenter.y = MAX(self.frame.size.height/2, MIN(screenSize.height - self.frame.size.height/2, newCenter.y));
    
    self.center = newCenter;
    touchLocation = currentLocation;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // إذا كانت لمسة خفيفة وليست سحباً، يتم تفعيل دالة تغيير الهوية
    UITouch *touch = [touches anyObject];
    CGPoint endLocation = [touch locationInView:self.superview];
    CGFloat distance = hypot(endLocation.x - touchLocation.x, endLocation.y - touchLocation.y);
    if (distance < 5.0) {
        [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
}
@end

// دالة إنشاء الزر وعرضه في نافذة مستقلة تعلو التطبيق
static void createFloatingButtonWindow() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingWindow) return;
        
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        
        if (scene) {
            floatingWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            floatingWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        
        floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        floatingWindow.backgroundColor = [UIColor clearColor];
        floatingWindow.hidden = NO;
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        floatingWindow.rootViewController = vc;
        
        // إنشاء الزر العائم
        SpoofFloatingButton *spoofButton = [SpoofFloatingButton buttonWithType:UIButtonTypeCustom];
        spoofButton.frame = CGRectMake(30, 120, 120, 42);
        spoofButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.45 blue:0.95 alpha:0.9];
        [spoofButton setTitle:@"🔄 تغيير الهوية" forState:UIControlStateNormal];
        [spoofButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        spoofButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        spoofButton.layer.cornerRadius = 21;
        spoofButton.layer.borderWidth = 1.5;
        spoofButton.layer.borderColor = [[UIColor whiteColor] CGColor];
        spoofButton.layer.shadowColor = [[UIColor blackColor] CGColor];
        spoofButton.layer.shadowOffset = CGSizeMake(0, 3);
        spoofButton.layer.shadowOpacity = 0.4;
        spoofButton.layer.shadowRadius = 4;
        
        [spoofButton addTarget:nil action:@selector(handleSpoofButtonTap) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:spoofButton];
    });
}

%ctor {
    @autoreleasepool {
        class_addMethod(objc_getMetaClass("NSObject"), @selector(handleSpoofButtonTap), (IMP)rotateIdentityNow, "v@:");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            createFloatingButtonWindow();
        });
    }
}

// الخطافات والآبي والـ IDFA كما هي
%hook NSLocale
+ (NSArray<NSString *> *)preferredLanguages {
    return @[@"en-US", @"en"];
}
- (NSString *)countryCode {
    return @"US";
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        NSString *activeIDFA = getDynamicIDFA();
        if (activeIDFA) {
            return [[NSUUID alloc] initWithUUIDString:activeIDFA];
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
+ (NSTimeZone *)systemTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
%end

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *activeIP = getDynamicIP();
        
        if (activeIP) {
            [modifiedHeaders setObject:activeIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:activeIP forKey:@"Client-IP"];
            [modifiedHeaders setObject:activeIP forKey:@"X-Real-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    @try {
        NSString *activeIP = getDynamicIP();
        if (field && activeIP && 
            ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
             [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
             [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
            %orig(activeIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setURL:(NSURL * _Nullable)url {
    %orig;
    @try {
        NSString *activeIP = getDynamicIP();
        if (url && url.absoluteString && activeIP) {
            [self setValue:activeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [self setValue:activeIP forHTTPHeaderField:@"Client-IP"];
            [self setValue:activeIP forHTTPHeaderField:@"X-Real-IP"];
        }
    } @catch (NSException *e) {}
}
%end
