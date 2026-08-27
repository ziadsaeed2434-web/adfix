#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 0.0;
static double sessionLongitude = 0.0;
static NSString *sessionCanadaIP = nil;

static void initializeNewSessionData() {
    // إحداثيات مدينة تورنتو، كندا (مع إحداث عشوائي بسيط لتغيير الموقع في كل جلسة)
    double randomLatOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    double randomLonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
    
    sessionLatitude = 43.6532 + randomLatOffset;
    sessionLongitude = -79.3832 + randomLonOffset;
    
    // نطاقات آبي كندية نظيفة وحقيقية (Rogers و Bell كندا) لضمان قبول الإعلانات
    NSArray *canadaIPRanges = @[
        [NSString stringWithFormat:@"99.224.%d.%d", arc4random_uniform(100) + 10, arc4random_uniform(254) + 1], // Rogers Toronto
        [NSString stringWithFormat:@"24.80.%d.%d", arc4random_uniform(100) + 10, arc4random_uniform(254) + 1],  // Shaw / Rogers BC-ON
        [NSString stringWithFormat:@"142.112.%d.%d", arc4random_uniform(50) + 10, arc4random_uniform(254) + 1], // Bell Canada
        [NSString stringWithFormat:@"184.144.%d.%d", arc4random_uniform(100) + 10, arc4random_uniform(254) + 1] // Telus / Bell Ontario
    ];
    
    int randomIndex = arc4random_uniform((int)[canadaIPRanges count]);
    sessionCanadaIP = canadaIPRanges[randomIndex];
}

%ctor {
    initializeNewSessionData();
}

// تثبيت موقع تورنتو، كندا الجغرافي
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(sessionLatitude, sessionLongitude);
}
%end

// إجبار إعدادات الشبكة على استخدام الآبي الكندي
%hook NSURLSessionConfiguration

- (void)setHTTPAdditionalHeaders:(NSDictionary *)HTTPAdditionalHeaders {
    NSMutableDictionary *modifiedHeaders = [HTTPAdditionalHeaders mutableCopy];
    if (!modifiedHeaders) {
        modifiedHeaders = [NSMutableDictionary dictionary];
    }
    
    [modifiedHeaders setObject:sessionCanadaIP forKey:@"X-Forwarded-For"];
    [modifiedHeaders setObject:sessionCanadaIP forKey:@"Client-IP"];
    [modifiedHeaders setObject:sessionCanadaIP forKey:@"X-Real-IP"];
    
    %orig(modifiedHeaders);
}

%end

// حقن الآبي الكندي في جميع الطلبات الصادرة
%hook NSMutableURLRequest

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        %orig(sessionCanadaIP, field);
        return;
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString) {
        [self setValue:sessionCanadaIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:sessionCanadaIP forHTTPHeaderField:@"Client-IP"];
    }
}

%end
