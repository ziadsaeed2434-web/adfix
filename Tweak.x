#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 33.7550;
static double sessionLongitude = -84.3900;
static NSString *dynamicSessionIP = @"144.160.12.88";
static NSString *sessionTimeZoneName = @"America/New_York";

static void generateATT_IP() {
    @try {
        int thirdSegment = arc4random_uniform(100) + 1; // نطاقات AT&T الحقيقية
        int fourthSegment = arc4random_uniform(254) + 1;
        dynamicSessionIP = [NSString stringWithFormat:@"144.160.%d.%d", thirdSegment, fourthSegment];
        
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7550 + latOffset;
        sessionLongitude = -84.3900 + lonOffset;
    } @catch (NSException *e) {}
}

%ctor {
    generateATT_IP();
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
