#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

static NSString *currentIDFV = nil;
static NSString *currentIDFA = nil;

// دالة توليد UUID آمنة ومستقرة تماماً
static NSString *generateNewUUID() {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    if (!uuid) return [[NSUUID UUID] UUIDString];
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    if (!string) return [[NSUUID UUID] UUIDString];
    
    NSString *result = [NSString stringWithString:(__bridge NSString *)string];
    CFRelease(string);
    return result;
}

// 1. خطاف معرف الجهاز (IDFV)
%hook UIDevice
- (NSUUID *)identifierForVendor {
    @try {
        if (!currentIDFV) {
            currentIDFV = generateNewUUID();
        }
        return [[NSUUID alloc] initWithUUIDString:currentIDFV];
    } @catch (NSException *e) {
        return %orig;
    }
}
%end

// 2. خطاف معرف الإعلانات (IDFA)
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        if (!currentIDFA) {
            currentIDFA = generateNewUUID();
        }
        return [[NSUUID alloc] initWithUUIDString:currentIDFA];
    } @catch (NSException *e) {
        return %orig;
    }
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end
