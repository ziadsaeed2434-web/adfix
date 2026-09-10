#import <Foundation/Foundation.h>

%hook NSBundle
- (NSString *)bundleIdentifier {
    // إرجاع البندل الأصلي لأي جهة تطلبه داخل التطبيق
    return @"com.codebysms";
}
%end
