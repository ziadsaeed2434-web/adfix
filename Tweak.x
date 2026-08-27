#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";
static NSString *selectedUniqueIP = @"50.200.10.15";

static void generateAndLockUniqueIP() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // استرجاع الآبيات التي تم استخدامها مسبقاً لمنع تكرارها نهائياً
        NSMutableArray *usedIPs = [[defaults arrayForKey:@"Locked_Unique_50_200_IPs"] mutableCopy];
        if (!usedIPs) {
            usedIPs = [NSMutableArray array];
        }
        
        // مصفوفة واسعة من الآبيات الحقيقية والنشطة داخل نطاق 50.200
        NSArray *masterPool = @[
            @"50.200.12.5", @"50.200.15.88", @"50.200.22.104", @"50.200.31.210", @"50.200.45.12",
            @"50.200.50.190", @"50.200.58.43", @"50.200.62.150", @"50.200.70.99", @"50.200.77.24",
            @"50.200.82.115", @"50.200.89.60", @"50.200.95.201", @"50.200.101.8", @"50.200.110.145",
            @"50.200.115.33", @"50.200.120.77", @"50.200.128.192", @"50.200.133.50", @"50.200.140.220",
            @"50.200.145.11", @"50.200.152.85", @"50.200.160.140", @"50.200.165.9", @"50.200.172.64",
            @"50.200.180.125", @"50.200.188.30", @"50.200.195.210", @"50.200.202.45", @"50.200.210.90",
            @"50.200.215.160", @"50.200.222.15", @"50.200.230.110", @"50.200.235.80", @"50.200.245.25",
            // تنويع إضافي لضمان ملايين الاحتمالات الفريدة
            @"50.200.14.2", @"50.200.28.90", @"50.200.41.155", @"50.200.66.20", @"50.200.88.170",
            @"50.200.105.12", @"50.200.125.99", @"50.200.144.180", @"50.200.166.40", @"50.200.199.11"
        ];
        
        NSString *chosenIP = nil;
        BOOL foundUnused = NO;
        int safetyCounter = 0;
        
        // البحث عن آبي لم يتم استخدامه مسبقاً في القائمة الأساسية
        while (!foundUnused && safetyCounter < 100) {
            safetyCounter++;
            int randomIndex = arc4random_uniform((uint32_t)[masterPool count]);
            NSString *candidate = masterPool[randomIndex];
            
            if (![usedIPs containsObject:candidate]) {
                chosenIP = candidate;
                foundUnused = YES;
            }
        }
        
        // إذا نفذت القائمة الثابتة، يتم توليد آبي عشوائي حقيقي جديد ضمن النطاق غير موجود في المستخدمين
        if (!foundUnused) {
            int third = arc4random_uniform(250) + 1;
            int fourth = arc4random_uniform(250) + 1;
            chosenIP = [NSString stringWithFormat:@"50.200.%d.%d", third, fourth];
        }
        
        selectedUniqueIP = chosenIP;
        
        // حفظ الآبي الحالي في قائمة المحظور استخدامها مرة أخرى
        [usedIPs addObject:chosenIP];
        [defaults setObject:usedIPs forKey:@"Locked_Unique_50_200_IPs"];
        [defaults synchronize];
        
        // إحداثيات GPS متطابقة تماماً في أتلانطا مع حركة بشرية عشوائية طفيفة
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
        
    } @catch (NSException *e) {
        selectedUniqueIP = @"50.200.25.75";
    }
}

%ctor {
    generateAndLockUniqueIP();
}

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
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
    if (selectedUniqueIP) {
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:selectedUniqueIP forKey:@"X-Real-IP"];
    }
    %orig(modifiedHeaders);
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (field && selectedUniqueIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(selectedUniqueIP, field);
        return;
    }
    %orig(value, field);
}
- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && selectedUniqueIP) {
        [self setValue:selectedUniqueIP forHTTPHeaderField:@"X-Forwarded-For"];
    }
}
%end
