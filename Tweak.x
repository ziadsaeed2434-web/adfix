#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 0.0;
static double sessionLongitude = 0.0;
static NSString *sessionAtlantaIP = nil;

static void initializeNewSessionData() {
    double randomLatOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double randomLonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    
    sessionLatitude = 33.7490 + randomLatOffset;
    sessionLongitude = -84.3880 + randomLonOffset;
    
    NSTimeInterval timeSeed = [[NSDate date] timeIntervalSince1970] * 1000;
    int uniqueSeed = (int)timeSeed % 90 + 10;
    int randomSubSegment = arc4random_uniform(254) + 1;
    
    sessionAtlantaIP = [NSString stringWithFormat:@"172.59.%d.%d", uniqueSeed, randomSubSegment];
}

%ctor {
    initializeNewSessionData();
}

// تثبيت موقع أتلانتا الجغرافي
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// إجبار إعدادات الشبكة على استخدام الآبي الجديد
%hook NSURLSessionConfiguration

- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy];
    if (!modifiedHeaders) {
        modifiedHeaders = [NSMutableDictionary dictionary];
    }
    
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"X-Forwarded-For"];
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"Client-IP"];
    [modifiedHeaders setObject:sessionAtlantaIP forKey:@"X-Real-IP"];
    
    %orig(modifiedHeaders);
}

%end

// حقن الآبي في جميع الطلبات الصادرة
%hook NSMutableURLRequest

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        %orig(sessionAtlantaIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString) {
        [self setValue:sessionAtlantaIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:sessionAtlantaIP forHTTPHeaderField:@"Client-IP"];
    }
}

%end
