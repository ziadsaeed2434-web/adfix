#import <UIKit/UIKit.h>

static BOOL isAutoRunning = NO;

@interface UIViewController (AutoEarn)
- (void)startAutomationLoop;
@end

// دالة محاكاة اللمس اليدوي الحقيقي (نفس طريقة لمس الإصبع تماماً)
static void simulateRealTouchAtPoint(CGPoint point) {
    UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject];
    if (!window) return;

    // إيجاد العنصر الموجود تحت الإحداثيات بدقة
    UIView *targetView = [window hitTest:point withEvent:nil];
    if (targetView) {
        // إنشاء حدث لمس نظامي متكامل (بداية اللمس ثم رفع الإصبع)
        UITouch *touch = [[UITouch alloc] init];
        NSSet *touches = [NSSet setWithObject:touch];
        
        // إرسال دورة اللمس للـ View لتستجيب إيماءات SwiftUI فوراً دون أي كراش
        [targetView touchesBegan:touches withEvent:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [targetView touchesEnded:touches withEvent:nil];
        });
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (isAutoRunning) return;
    isAutoRunning = YES;
    
    // بدء حلقة الأتمتة التلقائية بعد فتح الصفحة بثانيتين
    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
}

%end

@implementation UIViewController (AutoEarn)

- (void)startAutomationLoop {
    // 1. الضغط على زر "Shake & Earn"
    simulateRealTouchAtPoint(CGPointMake(215, 755));
    
    // 2. الانتظار ثم الضغط على "Start Shaking!"
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        simulateRealTouchAtPoint(CGPointMake(215, 890));
        
        // 3. الانتظار ثم الضغط على "Watch Ad & Earn"
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            simulateRealTouchAtPoint(CGPointMake(215, 630));
            
            // 4. الانتظار حتى ينتهي الإعلان (15 ثانية) ثم الضغط على "Awesome!"
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                simulateRealTouchAtPoint(CGPointMake(215, 630));
                
                // 5. الانتظار ثم الضغط على زر الرجوع للخلف (<) للعودة للقائمة الرئيسية وتكرار العملية من جديد
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    simulateRealTouchAtPoint(CGPointMake(45, 75));
                    
                    // إعادة تشغيل الحلقة التلقائية (Loop) من جديد باستمرار
                    isAutoRunning = NO;
                    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
                });
            });
        });
    });
}

@end
