#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// دالة آمنة ومستقرة لتوليد UUID عشوائي جديد بكل إستدعاء
static NSUUID *generateRandomNSUUID() {
    @try {
        CFUUIDRef theUUID = CFUUIDCreate(NULL);
        if (theUUID) {
            CFStringRef string = CFUUIDCreateString(NULL, theUUID);
            CFRelease(theUUID);
            if (string) {
                NSString *stringResult = [NSString stringWithString:(__bridge NSString *)string];
                CFRelease(string);
                return [[NSUUID alloc] initWithUUIDString:stringResult];
            }
        }
    } @catch (NSException *e) {}
    
    // حل بديل احتياطي آمن تماماً إذا فشلت الدالة الأولى
    return [NSUUID UUID];
}

%hook UIDevice

- (NSUUID *)identifierForVendor {
    // في كل مرة يطلب فيها التطبيق معرف الجهاز، سيحصل على معرف مختلف وعشوائي جديد
    return generateRandomNSUUID();
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    // في كل مرة يطلب فيها التطبيق معرف الإعلانات، سيحصل على معرف إعلانات مختلف وجديد
    return generateRandomNSUUID();
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end
