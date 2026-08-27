#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>
#import <sys/utsname.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";
static NSString *selectedUniqueIP = @"50.200.10.15";
static NSString *sessionFakeIDFA = nil;
static NSString *cleanUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";

static void generateUniqueSessionData() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. مسح الكوكيز والذاكرة المؤقتة تماماً لضمان بدء نظيف
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // 2. إدارة الآبيات لمنع التكرار نهائياً
        NSMutableArray *usedIPs = [[defaults arrayForKey:@"Locked_Unique_50_200_IPs"] mutableCopy];
        if (!usedIPs) {
            usedIPs = [NSMutableArray array];
        }
        
        NSArray *masterPool = @[
            @"50.200.12.5", @"50.200.15.88", @"50.200.22.104", @"50.200.31.210", @"50.200.45.12",
            @"50.200.50.190", @"50.200.58.43", @"50.200.62.150", @"50.200.70.99", @"50.200.77.24",
            @"50.200.82.115", @"50.200.89.60", @"50.200.95.201", @"50.200.101.8", @"50.200.110.145",
            @"50.200.115.33", @"50.200.120.77", @"50.200.128.192", @"50.200.133.50", @"50.200.140.220",
            @"50.200.145.11", @"50.200.152.85", @"50.200.160.140", @"50.200.165.9", @"50.200.172.64",
            @"50.200.180.125", @"50.200.188.30", @"50.200.195.210", @"50.200.202.45", @"50.200.210.90",
            @"50.200.215.160", @"50.200.222.15", @"50.200.230.110", @"50.200.235.80", @"50.200.245.25",
            @"50.200.14.2", @"50.200.28.90", @"50.200.41.155", @"50.200.66.20", @"50.200.88.170",
            @"50.200.105.12", @"50.200.125.99", @"50.200.144.180", @"50.200.166.40", @"50.200.199.11"
        ];
        
        NSString *chosenIP = nil;
        BOOL foundUnusedIP = NO;
        int safetyCounter = 0;
        
        while (!foundUnusedIP && safetyCounter < 100) {
            safetyCounter++;
            int randomIndex = arc4random_uniform((uint32_t)[masterPool count]);
            NSString *candidate = masterPool[randomIndex];
            
            if (![usedIPs containsObject:candidate]) {
                chosenIP = candidate;
                foundUnusedIP = YES;
            }
        }
        
        if (!foundUnusedIP) {
            int third = arc4random_uniform(250) + 1;
            int fourth = arc4random_uniform(250) + 1;
            chosenIP = [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
        }
        
        selectedUniqueIP = chosenIP;
        [usedIPs addObject:chosenIP];
        [defaults setObject:usedIPs forKey:@"Locked_Unique_50_200_IPs"];
        
        // 3. توليد IDFA جديد تماماً غير مستخدم مسبقاً
        NSMutableArray *usedIDFAs = [[defaults arrayForKey:@"Locked_Unique_IDFAs"] mutableCopy];
        if (!usedIDFAs) {
            usedIDFAs = [NSMutableArray array];
        }
        
        NSString *candidateIDFA = nil;
        BOOL foundUnusedIDFA = NO;
        int idfaCounter = 0;
        
        while (!foundUnusedIDFA && idfaCounter < 50) {
            idfaCounter++;
            NSString *newUUID = [[NSUUID UUID] UUIDString];
            if (![usedIDFAs containsObject:newUUID]) {
                candidateIDFA = newUUID;
                foundUnusedIDFA = YES;
            }
        }
        
        if (!candidateIDFA) {
            candidateIDFA = [[NSUUID UUID] UUIDString];
        }
        
        sessionFakeIDFA = candidateIDFA;
        [usedIDFAs addObject:candidateIDFA];
        [defaults setObject:usedIDFAs forKey:@"Locked_Unique_IDFAs"];
        [defaults synchronize];
        
        // 4. إحداثيات GPS عشوائية طفيفة في أتلانطا
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
        
    } @catch (NSException *e) {
        selectedUniqueIP = @"50.200.25.75";
        sessionFakeIDFA = [[NSUUID UUID] UUIDString];
    }
}

%ctor {
    // تأخير بشري بسيط (2 ثانية) لتهيئة البيئة بسلاسة قبل طلب الإعلانات
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        generateUniqueSessionData();
    });
}

// 1. إخفاء مسارات الجلبريك والفحوصات الأمنية لتجنب الحظر
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    if ([path containsString:@"Cydia"] || [path containsString:@"apt"] || [path containsString:@"jb"] || [path containsString:@"TrollStore"] || [path containsString:@"LiveContainer"]) {
        return NO;
    }
    return %orig;
}
%end

// 2. تزييف لغة الجهاز لتكون إنجليزية أمريكية مطابقة
%hook NSLocale
+ (NSArray<NSString *> *)preferredLanguages {
    return @[@"en-US", @"en"];
}
- (NSString *)countryCode {
    return @"US";
}
%end

// 3. تزييف معرف الإعلانات (IDFA) الفريد غير المكرر
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (sessionFakeIDFA) {
        return [[NSUUID alloc] initWithUUIDString:sessionFakeIDFA];
    }
    return %orig;
}
%end

// 4. مطابقة التوقيت الزمني لأتلانطا
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
+ (NSTimeZone *)systemTimeZone {
    return [NSTimeZone timeZoneWithName:sessionTimeZoneName] ?: %orig;
}
%end

// 5. مطابقة موقع الـ GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 6. حقن الآبي ومتصفح الـ User-Agent النظيف في ترويسات الشبكة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
    if (selectedUniqueIP) {
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"X-Real-IP"];
    }
    if (cleanUserAgent) {
        [modifiedHeaders setObject:cleanUserAgent forKey:@"User-Agent"];
    }
    %orig(modifiedHeaders);
}
%end

// 7. حقن الآبي والـ User-Agent في الطلبات الصادرة الفردية
%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (field && selectedUniqueIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(selectedUniqueIP, field);
        return;
    }
    if (field && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame && cleanUserAgent) {
        %orig(cleanUserAgent, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && selectedUniqueIP) {
        [self setValue:selectedUniqueIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:cleanUserAgent forHTTPHeaderField:@"User-Agent"];
    }
}
%end
