#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 33.7450;
static double sessionLongitude = -84.3850;
static NSString *dynamicSessionIP = @"73.140.95.22";
static NSString *sessionTimeZoneName = @"America/New_York";

static void generateComcastIP() {
    @try {
        int thirdSegment = arc4random_uniform(100) + 1; // نطاقات Comcast الحقيقية
        int fourthSegment = arc4random_uniform(254) + 1;
        dynamicSessionIP = [NSString stringWithFormat:@"73.140.%d.%d", thirdSegment, fourthSegment];
        
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7450 + latOffset;
        sessionLongitude = -84.3850 + lonOffset;
    } @catch (NSException *e) {}
}

%ctor {
    generateComcastIP();
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
    if (dynamicSessionIP) {
        [modifiedHeaders setObject:dynamicSessionIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:dynamicSessionIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:dynamicSessionIP forKey:@"X-Real-IP"];
    }
    %orig(modifiedHeaders);
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString * _Nonnull)field {
    if (field && dynamicSessionIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(dynamicSessionIP, field);
        return;
    }
    %orig(value, field);
}
- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && dynamicSessionIP) {
        [self setValue:dynamicSessionIP forHTTPHeaderField:@"X-Forwarded-For"];
    }
}
%end
