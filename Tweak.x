#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

// ================== متغيرات الجلسة ==================
static NSString *currentSessionUUID = nil;
static NSString *currentUserId      = nil;
static NSString *currentDeviceToken = nil;
static NSString *currentVoipToken   = nil;
static NSString *currentDeveloperId = nil;
static NSString *currentVendorID    = nil;
static NSString *currentAdID        = nil;
static NSString *currentDeviceName  = nil;

// ================== دوال مساعدة ==================
static NSString *randomHexString(NSUInteger length) {
    char *bytes = malloc(length);
    for (NSUInteger i = 0; i < length; i++)
        bytes[i] = "0123456789abcdef"[arc4random_uniform(16)];
    NSString *r = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    free(bytes); return r;
}
static NSString *randomUpperCaseHex(NSUInteger length) {
    char *bytes = malloc(length);
    for (NSUInteger i = 0; i < length; i++)
        bytes[i] = "0123456789ABCDEF"[arc4random_uniform(16)];
    NSString *r = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    free(bytes); return r;
}

// ================== 1) مسح Keychain ==================
static void clearKeychainExceptProtected(void) {
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword
    ];
    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
        };
        CFArrayRef result = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess) {
            NSArray *items = (__bridge_transfer NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(__bridge id)kSecAttrService];
                NSString *account = item[(__bridge id)kSecAttrAccount];
                if ([service isEqualToString:@"unique_device_id"] ||
                    [account isEqualToString:@"unique_device_id"]) continue;

                NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                [delQuery setObject:secClass forKey:(__bridge id)kSecClass];
                [delQuery removeObjectForKey:(__bridge id)kSecReturnAttributes];
                [delQuery removeObjectForKey:(__bridge id)kSecMatchLimit];
                SecItemDelete((__bridge CFDictionaryRef)delQuery);
            }
        }
    }
}

// ================== 2) مسح الـ Sandbox ==================
static void clearAppSandboxAggressive(void) {
    NSString *homeDir = NSHomeDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dirName in @[@"Documents", @"tmp"]) {
        NSString *dirPath = [homeDir stringByAppendingPathComponent:dirName];
        if ([fm fileExistsAtPath:dirPath]) {
            for (NSString *file in [fm contentsOfDirectoryAtPath:dirPath error:nil]) {
                [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:file] error:nil];
            }
        }
    }
    NSString *libraryPath = [homeDir stringByAppendingPathComponent:@"Library"];
    if ([fm fileExistsAtPath:libraryPath]) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:libraryPath error:nil]) {
            [fm removeItemAtPath:[libraryPath stringByAppendingPathComponent:item] error:nil];
        }
    }
}

// ================== 3) توليد المعرفات ==================
static void generateSessionIdentifiers(void) {
    currentSessionUUID = [[NSUUID UUID] UUIDString];
    currentUserId      = [[NSUUID UUID] UUIDString];
    currentDeveloperId = [[NSUUID UUID] UUIDString];
    currentVendorID    = [[NSUUID UUID] UUIDString];
    currentAdID        = [[NSUUID UUID] UUIDString];

    NSArray *deviceNames = @[@"iPhone", @"iPhone 13", @"iPhone 14 Pro", @"iPhone 15", @"My iPhone", @"Phone"];
    currentDeviceName = deviceNames[arc4random_uniform((uint32_t)deviceNames.count)];

    long long currentTimestampMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    double currentTimestampSec   = (double)currentTimestampMs / 1000.0;

    NSString *prefixHash    = randomHexString(64);
    NSString *appInstanceId = randomUpperCaseHex(32);
    NSString *diversionKey  = randomUpperCaseHex(5);
    NSString *hashedIdfa    = randomHexString(32);

    currentDeviceToken = [NSString stringWithFormat:
        @"\"%@]ple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
         "<plist version=\"1.0\">\n"
         "<dict>\n"
         "\t<key>/google/measurement/app_instance_id</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/app_version</key>\n"
         "\t<string>1.9.4</string>\n"
         "\t<key>/google/measurement/diversion_key</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/first_open_timestamp_ms</key>\n"
         "\t<integer>%lld</integer>\n"
         "\t<key>/google/measurement/gmp_app_id</key>\n"
         "\t<string>1:348263290411:ios:4a119dcfb912c688</string>\n"
         "\t<key>/google/measurement/hashed_idfa</key>\n"
         "\t<string>%@</string>\n"
         "\t<key>/google/measurement/last_delete_stale</key>\n"
         "\t<real>%f</real>\n"
         "\t<key>/google/measurement/last_engagement_end</key>\n"
         "\t<real>%f</real>\n"
         "\t<key>/google/measurement/midnight_offset</key>\n"
         "\t<real>66747.528999999995</real>\n"
         "\t<key>/google/measurement/os_version</key>\n"
         "\t<string>26.6.1</string>\n"
         "\t<key>/google/measurement/session_number</key>\n"
         "\t<integer>1</integer>\n"
         "</dict>\n"
         "</plist>",
         prefixHash, appInstanceId, diversionKey, currentTimestampMs,
         hashedIdfa, currentTimestampSec, (currentTimestampSec + 12.0)];

    currentVoipToken = [NSString stringWithFormat:@"\"%@%@\"]",
                        randomHexString(64), randomHexString(32)];
}

// ================== 4) كتابة القيم في NSUserDefaults + CFPreferences ==================
static void resetAndSetSessionUserDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    for (NSString *key in dict.allKeys) [defaults removeObjectForKey:key];
    [defaults synchronize];

    NSTimeInterval currentTimeMs = [[NSDate date] timeIntervalSince1970] * 1000;

    [defaults setObject:currentSessionUUID forKey:@"STASessionUUID"];
    [defaults setObject:currentUserId      forKey:@"igg-userId"];
    [defaults setObject:currentDeviceToken forKey:@"PingMe_Device_Token"];
    [defaults setObject:currentVoipToken   forKey:@"PingMe_VOIP_Token"];
    [defaults setObject:currentDeveloperId forKey:@"STAStoredDeveloperUserId"];
    [defaults setObject:currentVendorID    forKey:@"YTVendorID"];
    [defaults setObject:currentAdID        forKey:@"YTAdID"];
    [defaults setObject:@(currentTimeMs)   forKey:@"STACurrentSessionStartTime"];
    [defaults setObject:@(currentTimeMs)   forKey:@"STIFirstSessionTime"];
    [defaults setObject:@(currentTimeMs)   forKey:@"STAFirstSessionTime"];
    [defaults setObject:currentDeviceName  forKey:@"device_name"];

    [defaults setInteger:1 forKey:@"STASessionsNum"];
    [defaults setBool:YES  forKey:@"STAHtmlSplash"];
    [defaults setBool:YES  forKey:@"STAAppPresenceEnable"];
    [defaults setBool:YES  forKey:@"STALocalCache"];

    // كتابة إجبارية على القرص مرتين
    [defaults synchronize];

    // إجبار cfprefsd على الكتابة الفورية
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

// ================== 5) تحميل القيم الموجودة من القرص عند إعادة الفتح ==================
static void loadExistingSessionFromDisk(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *dt  = [defaults objectForKey:@"PingMe_Device_Token"];
    NSString *vt  = [defaults objectForKey:@"PingMe_VOIP_Token"];
    NSString *uid = [defaults objectForKey:@"igg-userId"];
    NSString *vid = [defaults objectForKey:@"YTVendorID"];
    NSString *aid = [defaults objectForKey:@"YTAdID"];
    NSString *dn  = [defaults objectForKey:@"device_name"];
    NSString *sid = [defaults objectForKey:@"STASessionUUID"];
    NSString *did = [defaults objectForKey:@"STAStoredDeveloperUserId"];

    // ملاحظة: هذه القراءة تمر عبر الهوك أدناه.
    // لذا نتجاوزها بـ CFPreferences لقراءة القيم الفعلية من القرص.
    CFPropertyListRef rDT  = CFPreferencesCopyAppValue(CFSTR("PingMe_Device_Token"), kCFPreferencesCurrentApplication);
    CFPropertyListRef rVT  = CFPreferencesCopyAppValue(CFSTR("PingMe_VOIP_Token"),   kCFPreferencesCurrentApplication);
    CFPropertyListRef rUID = CFPreferencesCopyAppValue(CFSTR("igg-userId"),          kCFPreferencesCurrentApplication);
    CFPropertyListRef rVID = CFPreferencesCopyAppValue(CFSTR("YTVendorID"),          kCFPreferencesCurrentApplication);
    CFPropertyListRef rAID = CFPreferencesCopyAppValue(CFSTR("YTAdID"),              kCFPreferencesCurrentApplication);
    CFPropertyListRef rDN  = CFPreferencesCopyAppValue(CFSTR("device_name"),         kCFPreferencesCurrentApplication);
    CFPropertyListRef rSID = CFPreferencesCopyAppValue(CFSTR("STASessionUUID"),      kCFPreferencesCurrentApplication);
    CFPropertyListRef rDID = CFPreferencesCopyAppValue(CFSTR("STAStoredDeveloperUserId"), kCFPreferencesCurrentApplication);

    if (rDT)  currentDeviceToken = [(__bridge NSString *)rDT copy];
    if (rVT)  currentVoipToken   = [(__bridge NSString *)rVT copy];
    if (rUID) currentUserId      = [(__bridge NSString *)rUID copy];
    if (rVID) currentVendorID    = [(__bridge NSString *)rVID copy];
    if (rAID) currentAdID        = [(__bridge NSString *)rAID copy];
    if (rDN)  currentDeviceName  = [(__bridge NSString *)rDN copy];
    if (rSID) currentSessionUUID = [(__bridge NSString *)rSID copy];
    if (rDID) currentDeveloperId = [(__bridge NSString *)rDID copy];

    if (rDT)  CFRelease(rDT);
    if (rVT)  CFRelease(rVT);
    if (rUID) CFRelease(rUID);
    if (rVID) CFRelease(rVID);
    if (rAID) CFRelease(rAID);
    if (rDN)  CFRelease(rDN);
    if (rSID) CFRelease(rSID);
    if (rDID) CFRelease(rDID);

    (void)dt; (void)vt; (void)uid; (void)vid; (void)aid; (void)dn; (void)sid; (void)did;
}

// ================== 6) نافذة عائمة شفافة ==================
@interface YT_FloatingWindow : UIWindow @end
@implementation YT_FloatingWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end

// ================== 7) منفّذ الزر ==================
@interface YT_Executor : NSObject
+ (void)install;
+ (void)buttonTapped:(UIButton *)sender;
+ (void)handlePan:(UIPanGestureRecognizer *)pan;
+ (void)runFullPipelineAndExit;
@end

static UIWindow *gFloatingWindow = nil;

@implementation YT_Executor

+ (void)install {
    if (gFloatingWindow) { gFloatingWindow.hidden = NO; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect frame = CGRectMake(20, 120, 70, 70);
        YT_FloatingWindow *win = [[YT_FloatingWindow alloc] initWithFrame:frame];
        win.windowLevel = UIWindowLevelAlert + 1000;
        win.backgroundColor = [UIColor clearColor];
        win.rootViewController = [UIViewController new];
        win.rootViewController.view.backgroundColor = [UIColor clearColor];
        win.hidden = NO;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = win.bounds;
        btn.backgroundColor = [UIColor colorWithRed:0.90 green:0.15 blue:0.15 alpha:0.95];
        btn.layer.cornerRadius  = 35.0;
        btn.layer.shadowColor   = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.4;
        btn.layer.shadowRadius  = 6.0;
        btn.layer.shadowOffset  = CGSizeMake(0, 3);
        [btn setTitle:@"تنفيذ" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [btn addTarget:self action:@selector(buttonTapped:)
      forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];

        [win.rootViewController.view addSubview:btn];
        gFloatingWindow = win;
    });
}

+ (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    CGPoint t = [pan translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [pan setTranslation:CGPointZero inView:v.superview];
}

+ (void)buttonTapped:(UIButton *)sender {
    sender.enabled = NO;
    sender.backgroundColor = [UIColor grayColor];
    [sender setTitle:@"..." forState:UIControlStateNormal];
    [self runFullPipelineAndExit];
}

+ (void)runFullPipelineAndExit {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        // ===== 1) مسح كل شيء =====
        clearAppSandboxAggressive();     // Documents + tmp + Library
        clearKeychainExceptProtected();  // Keychain (مع استثناء unique_device_id)

        // ===== 2) توليد كل المعرّفات الجديدة =====
        generateSessionIdentifiers();

        // ===== 3) كتابة كل القيم المزيفة =====
        resetAndSetSessionUserDefaults();

        // ===== 4) فرصة أخيرة لـ cfprefsd =====
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
        [[NSUserDefaults standardUserDefaults] synchronize];

        // ===== 5) انتظار مضمون قبل الخروج =====
        // مهم جداً: يعطي النظام وقتاً كافياً لكتابة plist على القرص
        [NSThread sleepForTimeInterval:1.5];

        // ===== 6) تأكيد إضافي ثم الخروج =====
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
        [[NSUserDefaults standardUserDefaults] synchronize];

        [NSThread sleepForTimeInterval:0.5];

        dispatch_async(dispatch_get_main_queue(), ^{
            exit(0);
        });
    });
}

@end

// ================== 8) عند التشغيل ==================
%ctor {
    // نحمّل أي قيم سبق كتابتها حتى تفرضها الهوكات من جديد
    loadExistingSessionFromDisk();

    // الزر يظهر دائماً
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [YT_Executor install];
    });

    [[NSNotificationCenter defaultCenter] addObserver:[YT_Executor class]
                                             selector:@selector(install)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

// ================== 9) هوك NSUserDefaults ==================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if (currentDeviceToken && [defaultName isEqualToString:@"PingMe_Device_Token"]) return currentDeviceToken;
    if (currentVoipToken   && [defaultName isEqualToString:@"PingMe_VOIP_Token"])   return currentVoipToken;
    if (currentUserId      && [defaultName isEqualToString:@"igg-userId"])          return currentUserId;
    if (currentDeviceName  && [defaultName isEqualToString:@"device_name"])         return currentDeviceName;
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    // تعديل القيمة فقط، ثم استدعاء %orig مرة واحدة فقط
    if (currentDeviceToken && [defaultName isEqualToString:@"PingMe_Device_Token"]) {
        value = currentDeviceToken;
    } else if (currentVoipToken && [defaultName isEqualToString:@"PingMe_VOIP_Token"]) {
        value = currentVoipToken;
    }
    %orig(value, defaultName);
}

%end

// ================== 10) تثبيت معرف البائع واسم الجهاز ==================
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentVendorID) return %orig;
    return [[NSUUID alloc] initWithUUIDString:currentVendorID];
}
- (NSString *)name {
    return currentDeviceName ?: %orig;
}
%end

// ================== 11) تثبيت معرف الإعلانات ==================
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!currentAdID) return %orig;
    return [[NSUUID alloc] initWithUUIDString:currentAdID];
}
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end
