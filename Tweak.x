#import <UIKit/UIKit.h>

static BOOL isAutoRunning = NO;

// دالة تنفذ النقر وتعرض دائرة حمراء مؤقتة في مكان النقرة لترى أين يضغط التويك
static void tapAtPointWithVisual(CGPoint point) {
    UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject];
    if (window) {
        // إنشاء دائرة حمراء صغيرة مرئية عند الإحداثيات لتوضيح مكان النقرة
        UIView *debugDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        debugDot.center = point;
        debugDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.6]; // حمراء شفافة
        debugDot.layer.cornerRadius = 20;
        debugDot.layer.zPosition = 999999; // تظهر فوق كل العناصر
        [window addSubview:debugDot];
        
        // إزالة الدائرة بعد نصف ثانية
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [debugDot removeFromSuperview];
        });
    }

    // محاكاة اللمس الفعلية
    CGEventRef down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, point, kCGMouseButtonLeft);
    CGEventRef up = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, point, kCGMouseButtonLeft);
    
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    
    CFRelease(down);
    CFRelease(up);
}

// مراقبة الشاشة وبدء الأتمتة
%hook UIHostingController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (isAutoRunning) return;
    isAutoRunning = YES;
    
    [self startAutomationLoop];
}

%end

@interface UIHostingController (AutoEarn)
- (void)startAutomationLoop;
@end

@implementation UIHostingController (AutoEarn)

- (void)startAutomationLoop {
    // 1. الضغط على زر Shake & Earn
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!isAutoRunning) return;
        tapAtPointWithVisual(CGPointMake(215, 750));
        
        // 2. الضغط على Start Shaking!
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            tapAtPointWithVisual(CGPointMake(215, 900));
            
            // 3. الضغط على Watch Ad & Earn
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                tapAtPointWithVisual(CGPointMake(215, 630));
                
                // 4. الضغط على Awesome! بعد انتهاء الإعلان
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    tapAtPointWithVisual(CGPointMake(215, 630));
                    
                    // 5. الرجوع للخلف عبر سهم الأعلى (<)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        tapAtPointWithVisual(CGPointMake(50, 80));
                        
                        // التكرار المستمر
                        isAutoRunning = NO;
                        [self startAutomationLoop];
                    });
                });
            });
        });
    });
}

@end
