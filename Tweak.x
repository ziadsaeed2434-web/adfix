#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

// مصفوفة الـ 22 نطاقاً عالمياً (فرنسا، هولندا، أمريكا، كندا، بريطانيا، ألمانيا)
static NSArray *g_baseIPPrefixes = nil;

static void initializeIPPrefixes() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_baseIPPrefixes = @[
            // --- فرنسا: Orange & Free ---
            @"80.12.60", @"80.15.80", @"193.250.30", @"82.64.12", @"213.228.0",
            // --- هولندا: KPN & VodafoneZiggo ---
            @"213.75.12", @"213.77.40", @"84.241.10", @"82.161.180",
            // --- أمريكا: AT&T Fiber & Verizon & Comcast ---
            @"32.211.132", @"32.215.135", @"68.192.33", @"68.200.14", @"24.180.52", @"71.34.120",
            // --- كندا: Rogers & Bell Canada ---
            @"24.212.32", @"142.112.10", @"142.116.22",
            // --- بريطانيا وألمانيا: BT & Deutsche Telekom ---
            @"81.134.12", @"82.165.11", @"79.200.12", @"84.113.20"
        ];
    });
}

// دالة توليد آبي ديناميكي محمية بالكامل
static NSString *generateDynamicGlobalIP() {
    @try {
        initializeIPPrefixes();
        if (!g_baseIPPrefixes || [g_baseIPPrefixes count] == 0) {
            return @"80.12.60.1";
        }
        int prefixIndex = arc4random_uniform((uint32_t)[g_baseIPPrefixes count]);
        NSString *selectedPrefix = g_baseIPPrefixes[prefixIndex];
        int lastOctet1 = 1 + arc4random_uniform(254);
        int lastOctet2 = 1 + arc4random_uniform(254);
        return [NSString stringWithFormat:@"%@.%d.%d", selectedPrefix, lastOctet1, lastOctet2];
    } @catch (NSException *e) {
        return @"80.12.60.1";
    }
}

static NSString *getSecureUUID(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [defaults stringForKey:key];
    if (!uuid) {
        uuid = [[NSUUID UUID] UUIDString];
        [defaults setObject:uuid forKey:key];
        [defaults synchronize];
    }
    return uuid;
}

static CLLocationCoordinate2D getGlobalAdCoordinate() {
    return CLLocationCoordinate2DMake(48.8566, 2.3522); // باريس، فرنسا
}

%ctor {
    @autoreleasepool {
        initializeIPPrefixes();
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"DynamicAdSessionIDFA"];
        [defaults removeObjectForKey:@"DynamicAdVendorID"];
        [defaults synchronize];
    }
}

%hook UIDevice
- (NSUUID *)identifierForVendor {
    @try {
        return [[NSUUID alloc] initWithUUIDString:getSecureUUID(@"DynamicAdVendorID")];
    } @catch (NSException *e) {}
    return %orig;
}
- (NSString *)systemVersion {
    return @"17.5";
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        return [[NSUUID alloc] initWithUUIDString:getSecureUUID(@"DynamicAdSessionIDFA")];
    } @catch (NSException *e) {}
    return %orig;
}
%end

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return getGlobalAdCoordinate();
}
%end

// 1. حقن الآبي في جلسات الشبكة العامة
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    @try {
        NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *dynamicIP = generateDynamicGlobalIP();
        if (dynamicIP) {
            [modifiedHeaders setObject:dynamicIP forKey:@"X-Forwarded-For"];
            [modifiedHeaders setObject:dynamicIP forKey:@"Client-IP"];
        }
        %orig(modifiedHeaders);
    } @catch (NSException *e) {
        %orig;
    }
}
%end

// 2. حقن إجباري ومباشر في كل طلب فردي يتم إنشاؤه عبر الطلبات (لضمان مرور كل الطلبات)
%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    @try {
        if (field && ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
                      [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame)) {
            NSString *dynamicIP = generateDynamicGlobalIP();
            %orig(dynamicIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    @try {
        if (field && ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
                      [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame)) {
            NSString *dynamicIP = generateDynamicGlobalIP();
            %orig(dynamicIP, field);
            return;
        }
        %orig(value, field);
    } @catch (NSException *e) {
        %orig(value, field);
    }
}
%end

