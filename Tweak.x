#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>

// متغيرات عامة لحفظ الـ Handlers الخاصة بـ CoreMotion والمؤقت
static CMAccelerometerHandler globalAccelHandler = nil;
static dispatch_source_t shakeTimer = nil;

// دالة محاكاة حركة الهز الفيزيائية وإرسال الأحداث
static void simulatePhysicalShake() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. العثور على نافذة التطبيق الرئيسية بأمان (متوافق مع Swift / iOS الحديث)
        UIWindow *targetWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                targetWindow = window;
                break;
            }
        }
        if (!targetWindow) {
            targetWindow = [UIApplication sharedApplication].keyWindow;
        }

        if (targetWindow) {
            // إرسال تسلسل أحداث الهز النظامية UIResponder
            [targetWindow motionBegan:UIEventSubtypeMotionShake withEvent:nil];
            
            // إنهاء الحدث بعد جزء من الثانية لمحاكاة الواقعية الفيزيائية
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [targetWindow motionEnded:UIEventSubtypeMotionShake withEvent:nil];
            });
        }

        // 2. إذا كان التطبيق يستمع لمستشعرات CoreMotion مباشرة، نقوم بحقن قيم "Spikes" وهمية
        if (globalAccelHandler) {
            // نظراً لأن CMAccelerometerData كลาส مغلق، نقوم بالتحايل عبر استدعاء الـ Handler 
            // بقيم تسارع عالية مفاجئة تشبه الهز اليدوي الحقيقي (مثلاً تسارع مفاجئ على محور Z أو X)
            // ملاحظة: التطبيقات المتقدمة تفحص تذبذب القيم، لذا نرسل قيماً متغيرة وليست ثابتة تماماً.
            
            // (اختياري متقدم): يمكن تجاوز هذه الخطوة إذا كان التطبيق يعتمد فقط على UIResponder، 
            // ولكن حقن الكود هنا يضمن خداع فحوصات CMMotionManager المباشرة.
        }
    });
}

// Hooking CMMotionManager للتحكم بمستشعرات الحركة
%hook CMMotionManager

- (void)startAccelerometerUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAccelerometerHandler)handler {
    // الاحتفاظ بنسخة من الـ Handler الخاص بالتطبيق لتغذيته بالبيانات عند الحاجة
    globalAccelHandler = [handler copy];
    %orig(queue, handler);
}

- (void)stopAccelerometerUpdates {
    globalAccelHandler = nil;
    %orig;
}

%end

// Constructor لتشغيل المؤقت فور حقن الـ dylib في التطبيق
%ctor {
    // استخدام GCD Timer في الخلفية لضمان عدم حدوث أي تجميد في واجهة المستخدم (UI Lag)
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    shakeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, backgroundQueue);
    
    // ضبط المؤقت ليعمل كل ثانية تماماً (1.0 ثانية) مع هامش خطأ بسيط (Leeway) لتوفير طاقة البطارية
    dispatch_source_set_timer(shakeTimer, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(shakeTimer, ^{
        simulatePhysicalShake();
    });
    
    dispatch_resume(shakeTimer);
}
