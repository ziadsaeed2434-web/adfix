#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/ASIdentifierManager.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionUSIP = @"172.58.15.42";
static NSString *sessionFakeIDFA = nil;
static NSString *sessionFakeIDFV = nil;
static NSString *sessionTimeZoneName = @"America/New_York";

typedef struct {
    NSString *ipRangeFormat;
    double baseLatitude;
    double baseLongitude;
    NSString *timeZoneName;
} IPLocationInfo;

static void initializeSessionData() {
    @try {
        NSTimeInterval timeSeed = [[NSDate date] timeIntervalSince1970] * 1000;
        int dynamicSegment = (int)((long)timeSeed % 90) + 10;
        int randomSubSegment = arc4random_uniform(254) + 1;
        
        IPLocationInfo realCarrierPool[] = {
            {@"172.58.%d.%d", 33.7490, -84.3880, @"America/New_York"},   // T-Mobile Atlanta
            {@"172.59.%d.%d", 33.7490, -84.3880, @"America/New_York"},   // T-Mobile Atlanta
            {@"166.199.%d.%d", 40.7128, -74.0060, @"America/New_York"},  // Verizon New York
            {@"166.137.%d.%d", 40.7128, -74.0060, @"America/New_York"},  // Verizon New York
            {@"144.160.%d.%d", 32.7767, -96.7970, @"America/Chicago"},   // AT&T Dallas
            {@"32.220.%d.%d", 32.7767, -96.7970, @"America/Chicago"},    // AT&T Dallas
            {@"73.140.%d.%d", 41.8781, -87.6298, @"America/Chicago"},    // Comcast Chicago
            {@"24.180.%d.%d", 34.0522, -118.2437, @"America/Los_Angeles"} // Spectrum Los Angeles
        };
        
        int poolSize = sizeof(realCarrierPool) / sizeof(IPLocationInfo);
        int randomIndex = arc4random_uniform(poolSize);
        IPLocationInfo selectedLocation = realCarrierPool[randomIndex];
        
        if (selectedLocation.ipRangeFormat) {
            if ([selectedLocation.ipRangeFormat containsString:@"166."]) {
                sessionUSIP = [NSString stringWithFormat:selectedLocation.ipRangeFormat, dynamicSegment % 50, randomSubSegment];
            } else {
                sessionUSIP = [NSString stringWithFormat:selectedLocation.ipRangeFormat, dynamicSegment, randomSubSegment];
            }
        }
        
        double randomLatOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double randomLonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        
        sessionLatitude = selectedLocation.baseLatitude + randomLatOffset;
        sessionLongitude = selectedLocation.baseLongitude + randomLonOffset;
        
        if (selectedLocation.timeZoneName) {
            sessionTimeZoneName = selectedLocation.timeZoneName;
        }
    } @catch (NSException *exception) {
        // حماية ضد أي خطأ مفاجئ أثناء التهيئة
    }
    
    sessionFakeIDFA = [[NSUUID UUID] UUIDString];
    sessionFakeIDFV = [[NSUUID UUID] UUIDString];
}

%ctor {
    initializeSessionData();
}

// 1. تزييف الـ IDFA بأمان
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (sessionFakeIDFA) {
        return [[NSUUID alloc] initWithUUIDString:sessionFakeIDFA];
    }
    return %orig;
}
%end

// 2. تزييف معرف الجهاز بأمان
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (sessionFakeIDFV) {
        return [[NSUUID alloc] initWithUUIDString:sessionFakeIDFV];
    }
    return %orig;
}
%end

// 3. مطابقة التوقيت الزمني بأمان
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    if (sessionTimeZoneName) {
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:sessionTimeZoneName];
        if (tz) return tz;
    }
    return %orig;
}
+ (NSTimeZone *)systemTimeZone {
    if (sessionTimeZoneName) {
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:sessionTimeZoneName];
        if (tz) return tz;
    }
    return %orig;
}
%end

// 4. مطابقة موقع الـ GPS
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// 5. حقن الآبي في ترويسات الشبكة والطلبات الصادرة بدون كراش
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy];
    if (!modifiedHeaders) {
        modifiedHeaders = [NSMutableDictionary dictionary];
    }
    if (sessionUSIP) {
        [modifiedHeaders setObject:sessionUSIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:sessionUSIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:sessionUSIP forKey:@"X-Real-IP"];
    }
    %orig(modifiedHeaders);
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString * _Nonnull)field {
    if (field && sessionUSIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(sessionUSIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && sessionUSIP) {
        [self setValue:sessionUSIP forHTTPHeaderField:@"X-Forwarded-For"];
    }
}
%end
