#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";

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
        
        // توليد هوية جديدة فورية
        getDynamicIP();
        getDynamicIDFA();
        
        // إحداثيات جديدة
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
    } @catch (NSException *e) {}
}

// إضافة زر عائم (Floating Button) يظهر فوق الشاشة لتغيير الهوية بضغطة زر
%hook UIApplication
- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) {
            keyWindow = [[UIApplication sharedApplication] windows].firstObject;
        }
        
        if (keyWindow) {
            // إنشاء زر عائم صغير في الشاشة
            UIButton *spoofButton = [UIButton buttonWithType:UIButtonTypeCustom];
            spoofButton.frame = CGRectMake(20, 100, 110, 40);
            spoofButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.85];
            [spoofButton setTitle:@"🔄 تغيير الهوية" forState:UIControlStateNormal];
            [spoofButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            spoofButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
            spoofButton.layer.cornerRadius = 10;
            spoofButton.layer.shadowColor = [[UIColor blackColor] CGColor];
            spoofButton.layer.shadowOffset = CGSizeMake(0, 2);
            spoofButton.layer.shadowOpacity = 0.5;
            spoofButton.layer.shadowRadius = 3;
            
            // ربط الضغط على الزر بدالة تغيير الآبي والـ IDFA
            [spoofButton addTarget:nil action:@selector(handleSpoofButtonTap) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:spoofButton];
            [keyWindow bringSubviewToFront:spoofButton];
        }
    });
}
%end

// تعريف الفعالية عند الضغط على الزر (بدون رسائل مزعجة، يتغير كل شي بصمت)
%ctor {
    @autoreleasepool {
        // إضافة دالة الاستجابة للزر برمجياً
        class_addMethod(objc_getMetaClass("NSObject"), @selector(handleSpoofButtonTap), (IMP)rotateIdentityNow, "v@:");
    }
}

// 1. تزييف لغة النظام
%hook NSLocale
+ (NSArray<NSString *> *)preferredLanguages {
    return @[@"en-US", @"en"];
}
- (NSString *)countryCode {
    return @"US";
}
%end

// 2. إرجاع الـ IDFA المتجدد
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

// 3. مطابقة التوقيت الزمني
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
+ (NSTimeZone *)systemTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
%end

// 4. مطابقة الـ GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 5. حقن الآبي في إعدادات الشبكة
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

// 6. حقن الآبي في الطلبات الصادرة
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
