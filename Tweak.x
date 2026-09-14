#import <UIKit/UIKit.h>

static BOOL isAutoRunning = NO;

@interface UIViewController (AutoEarn)
- (void)startAutomationLoop;
@end

// دالة الضغط التي تبحث عن الـ Gesture Recognizer وتفعله مباشرة في SwiftUI
static void tapAtPointWithVisual(CGPoint point) {
    UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject];
    if (window) {
        // دائرة حمراء مرئية لتتأكد بنفسك من مكان النقر
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

    // إيجاد العنصر وتفعيل الـ Actions المرتبطة به في SwiftUI
    UIView *targetView = [window hitTest:point withEvent:nil];
    if (targetView) {
        UIView *tempView = targetView;
        BOOL actionFired = NO;
        
        // البحث الصاعد في الـ Superviews عن أي Gesture Recognizer خاص بالزر وتفعيل الـ Targets الخاصة به
        while (tempView && !actionFired) {
            for (UIGestureRecognizer *recognizer in tempView.gestureRecognizers) {
                // استخراج الـ targets والـ actions الخاصة بالإيماءة وتشغيلها برمجياً
                NSArray *targets = [recognizer valueForKey:@"targets"];
                for (id targetEntry in targets) {
                    id target = [targetEntry valueForKey:@"target"];
                    SEL action = NSSelectorFromString([targetEntry valueForKey:@"action"]);
                    if (target && [target respondsToSelector:action]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [target performSelector:action withObject:recognizer];
                        #pragma clang diagnostic pop
                        actionFired = YES;
                        break;
                    }
                }
            }
            tempView = tempView.superview;
        }
        
        // كحتياط إضافي إذا كان العنصر UIControl تقليدي
        UIResponder *responder = targetView;
        while (responder && ![responder isKindOfClass:[UIControl class]] && [responder nextResponder]) {
            responder = [responder nextResponder];
        }
        if ([responder isKindOfClass:[UIControl class]]) {
            [(UIControl *)responder sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (isAutoRunning) return;
    isAutoRunning = YES;
    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
}

%end

@implementation UIViewController (AutoEarn)

- (void)startAutomationLoop {
    // 1. الضغط على زر Shake & Earn
    tapAtPointWithVisual(CGPointMake(215, 755));
    
    // 2. الضغط على Start Shaking!
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        tapAtPointWithVisual(CGPointMake(215, 890));
        
        // 3. الضغط على Watch Ad & Earn
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            tapAtPointWithVisual(CGPointMake(215, 630));
            
            // 4. الضغط على Awesome! بعد انتهاء الإعلان
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                tapAtPointWithVisual(CGPointMake(215, 630));
                
                // 5. الرجوع للخلف (<)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    tapAtPointWithVisual(CGPointMake(45, 75));
                    
                    isAutoRunning = NO;
                    [self performSelector:@selector(startAutomationLoop) withObject:nil afterDelay:2.0];
                });
            });
        });
    });
}

@end
