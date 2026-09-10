#import <Foundation/Foundation.h>

%hook NSBundle

- (NSString *)bundleIdentifier {
    // إذا كان الاستدعاء للـ Main Bundle (التطبيق الرئيسي نفسه)
    if (self == [NSBundle mainBundle]) {
        
        // هل الطلب صادر من مdee داخل الكود الأساسي للتطبيق؟ أم من مكتبة خارجية؟
        // للتأكد بنسبة أكبر، يمكننا إرجاع البندل الأصلي إذا كان المتصل ليس واجهة التطبيق الرئيسية (UIKit)
        NSArray *callStack = [NSThread callStackSymbols];
        
        // إذا كان الاستدعاء ليس من واجهة المستخدم أو النظام الداخلي البحت، نعيد البندل الأصلي
        BOOL isSystemOrUI = NO;
        if (callStack.count > 1) {
            NSString *caller = callStack[1];
            if ([caller containsString:@"UIKitCore"] || [caller containsString:@"Foundation"] || [caller containsString:@"CoreFoundation"]) {
                isSystemOrUI = YES;
            }
        }
        
        if (!isSystemOrUI) {
            // أي مكتبة خارجية (إعلانات، تحليلات، إلخ) تطلب البندل من الـ MainBundle ستحصل على الأصلي فوراً!
            return @"com.codebysms";
        }
    }
    
    return %orig;
}

%end
