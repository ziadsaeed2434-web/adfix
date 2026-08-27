#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *dynamicSessionIP = @"172.58.15.42";
static NSString *sessionTimeZoneName = @"America/New_York";

static void generateT_MobileIP() {
    @try {
        int thirdSegment = arc4random_uniform(50) + 50; // نطاقات T-Mobile الحقيقية
        int fourthSegment = arc4random_uniform(254) + 1;
        dynamicSessionIP = [NSString stringWithFormat:@"172.58.%d.%d", thirdSegment, fourthSegment];
        
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
    } @catch (NSException *e) {}
}

%ctor {
    generateT_MobileIP();
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
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
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
