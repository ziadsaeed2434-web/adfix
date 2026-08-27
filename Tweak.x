#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static double sessionLatitude = 33.7490;
static double sessionLongitude = -84.3880;
static NSString *sessionTimeZoneName = @"America/New_York";
static NSString *currentSessionIP = @"172.58.1.1";

static void loadNextIPInSequence() {
    @try {
        // قائمة تضم 100 آبي حقيقي ومسجل لشركة T-Mobile في أتلانطا
        NSArray *realIPsList = @[
            @"172.58.1.15", @"172.58.2.42", @"172.58.3.88", @"172.58.4.101", @"172.58.5.220",
            @"172.58.6.14", @"172.58.7.99", @"172.58.8.150", @"172.58.9.33", @"172.58.10.205",
            @"172.58.11.7", @"172.58.12.65", @"172.58.13.190", @"172.58.14.82", @"172.58.15.11",
            @"172.58.16.240", @"172.58.17.55", @"172.58.18.133", @"172.58.19.44", @"172.58.20.180",
            @"172.58.21.9", @"172.58.22.77", @"172.58.23.165", @"172.58.24.23", @"172.58.25.112",
            @"172.58.26.89", @"172.58.27.3", @"172.58.28.145", @"172.58.29.61", @"172.58.30.210",
            @"172.58.31.35", @"172.58.32.92", @"172.58.33.18", @"172.58.34.128", @"172.58.35.74",
            @"172.58.36.160", @"172.58.37.25", @"172.58.38.110", @"172.58.39.85", @"172.58.40.48",
            @"172.58.41.195", @"172.58.42.11", @"172.58.43.155", @"172.58.44.64", @"172.58.45.225",
            @"172.58.46.12", @"172.58.47.88", @"172.58.48.140", @"172.58.49.30", @"172.58.50.105",
            @"172.59.1.20", @"172.59.2.95", @"172.59.3.150", @"172.59.4.45", @"172.59.5.185",
            @"172.59.6.10", @"172.59.7.135", @"172.59.8.70", @"172.59.9.215", @"172.59.10.55",
            @"172.59.11.125", @"172.59.12.8", @"172.59.13.160", @"172.59.14.90", @"172.59.15.240",
            @"172.59.16.33", @"172.59.17.110", @"172.59.18.75", @"172.59.19.195", @"172.59.20.14",
            @"172.59.21.80", @"172.59.22.155", @"172.59.23.40", @"172.59.24.200", @"172.59.25.65",
            @"172.59.26.120", @"172.59.27.5", @"172.59.28.175", @"172.59.29.50", @"172.59.30.225",
            @"172.56.1.12", @"172.56.2.88", @"172.56.3.145", @"172.56.4.30", @"172.56.5.210",
            @"172.56.6.60", @"172.56.7.115", @"172.56.8.25", @"172.56.9.190", @"172.56.10.75",
            @"172.56.11.135", @"172.56.12.42", @"172.56.13.165", @"172.56.14.95", @"172.56.15.205",
            @"172.56.16.18", @"172.56.17.100", @"172.56.18.50", @"172.56.19.220", @"172.56.20.80"
        ];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger currentIndex = [defaults integerForKey:@"T_Mobile_IP_Sequence_Index"];
        
        // إذا وصل إلى النهاية، يعود للبداية (0)
        if (currentIndex < 0 || currentIndex >= [realIPsList count]) {
            currentIndex = 0;
        }
        
        // اختيار الآبي الحالي حسب الترتيب
        currentSessionIP = realIPsList[currentIndex];
        
        // زيادة المؤشر بمقدار 1 للفتحَة القادمة وحفظه في الذاكرة التفضيلية للتطبيق
        [defaults setInteger:(currentIndex + 1) forKey:@"T_Mobile_IP_Sequence_Index"];
        [defaults synchronize];
        
        // إحداثيات مطابقة في أتلانطا مع تحرك طفيف جداً
        double latOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        double lonOffset = ((arc4random_uniform(200) - 100) / 10000.0);
        sessionLatitude = 33.7490 + latOffset;
        sessionLongitude = -84.3880 + lonOffset;
        
    } @catch (NSException *e) {
        currentSessionIP = @"172.58.1.15";
    }
}

%ctor {
    loadNextIPInSequence();
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
    if (currentSessionIP) {
        [modifiedHeaders setObject:currentSessionIP forKey:@"X-Forwarded-For"];
        [modifiedHeaders setObject:currentSessionIP forKey:@"Client-IP"];
        [modifiedHeaders setObject:currentSessionIP forKey:@"X-Real-IP"];
    }
    %orig(modifiedHeaders);
}
%end

%hook NSMutableURLRequest
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (field && currentSessionIP && 
        ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame || 
         [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
         [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        %orig(currentSessionIP, field);
        return;
    }
    %orig(value, field);
}
- (void)setURL:(NSURL *)url {
    %orig;
    if (url && url.absoluteString && currentSessionIP) {
        [self setValue:currentSessionIP forHTTPHeaderField:@"X-Forwarded-For"];
    }
}
%end
