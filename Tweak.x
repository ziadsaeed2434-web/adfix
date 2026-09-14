#import <UIKit/UIKit.h>

static BOOL isAutoRunning = NO;

// تعريف واجهة تفصيلية لتجنب أخطاء المترجم
@interface UIHostingController : UIViewController
- (void)startAutomationLoop;
@end

// دالة النقر الآمنة والمرئية دون استخدام CGEvent المعقدة
static void tapAtPointWithVisual(CGPoint point) {
    UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject];
    if (window) {
        // إنشاء دائرة حمراء شفافة لتتبع مكان النقر على الشاشة
        UIView *debugDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        debugDot.center = point;
        debugDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.6];
        debugDot.layer.cornerRadius = 20;
        debugDot.layer.zPosition = 999999;
        [window addSubview:debugDot];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [debugDot removeFromSuperview];
        });
    }

    // إيجاد العنصر البرمجي في هذه النقطة ومحاكاة الضغط عليه بأمان تام
    UIView *hitView = [window hitTest:point withEvent:nil];
    if (hitView) {
        // إرسال حدث الضغط مباشرة للـ View المستهدف
        [hitView touchesBegan:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:nil];
        [hitView touchesEnded:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:nil];
    }
}

// هوك على أي UIViewController أو واجهة عامة لضمان عمل التويك فور ظهور الشاشة
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // التأكد من أننا داخل التطبيق المستهدف وأن الكود لا يتكرر بلا نهاية
    if (isAutoRunning) return;
    
    // التحقق من اسم الـ Controller أو تركها تعمل بشكل عام إذا كانت هذه هي صفحة التطبيق
    isAutoRunning = YES;
    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
}

%end

@implementation UIViewController (AutoEarn)

- (void)startAutomationLoop {
    // 1. الضغط على زر Shake & Earn
    tapAtPointWithVisual(CGPointMake(215, 750));
    
    // 2. الضغط على Start Shaking! بعد ثانيتين
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        tapAtPointWithVisual(CGPointMake(215, 900));
        
        // 3. الضغط على Watch Ad & Earn
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            tapAtPointWithVisual(CGPointMake(215, 630));
            
            // 4. الضغط على Awesome! بعد انتهاء الإعلان (15 ثانية)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                tapAtPointWithVisual(CGPointMake(215, 630));
                
                // 5. الرجوع للخلف عبر سهم الأعلى (<)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    tapAtPointWithVisual(CGPointMake(50, 80));
                    
                    // إعادة تفعيل الحالة لتكرار اللوب
                    isAutoRunning = NO;
                    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
                });
            });
        });
    });
}

@end
