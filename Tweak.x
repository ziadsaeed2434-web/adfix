#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// متغيرات عامة لمنع التكرار السريع
static NSTimer *fastTimer = nil;
static NSTimer *restartTimer = nil;
static NSString *lastTappedButton = nil;
static NSTimeInterval lastTapTime = 0;

// 1. دالة مساعدة للبحث عن أي UIView يحتوي على نص معين
UIView* findViewWithText(UIView *parentView, NSString *searchText) {
    if (!parentView) return nil;
    
    if ([parentView isKindOfClass:[UILabel class]] || [parentView isKindOfClass:[UIButton class]]) {
        NSString *text = nil;
        if ([parentView isKindOfClass:[UILabel class]]) {
            text = ((UILabel *)parentView).text;
        } else {
            text = [(UIButton *)parentView titleForState:UIControlStateNormal];
        }
        
        if (text && [text rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return parentView;
        }
    }
    
    for (UIView *subview in parentView.subviews) {
        UIView *foundView = findViewWithText(subview, searchText);
        if (foundView) {
            return foundView;
        }
    }
    return nil;
}

// 2. دالة مساعدة للبحث عن زر يحتوي على نص معين
UIButton* findButtonWithText(UIView *parentView, NSString *searchText) {
    if (!parentView) return nil;
    
    if ([parentView isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)parentView;
        NSString *buttonTitle = [button titleForState:UIControlStateNormal];
        if (buttonTitle && [buttonTitle rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return button;
        }
    }
    
    for (UIView *subview in parentView.subviews) {
        UIButton *foundButton = findButtonWithText(subview, searchText);
        if (foundButton) {
            return foundButton;
        }
    }
    return nil;
}

// 3. دالة محاكاة الضغط مع حماية من التكرار اللحظي
void simulateButtonTap(UIButton *button) {
    if (!button || !button.enabled || button.hidden || button.alpha == 0) return;
    
    NSString *buttonTitle = [button titleForState:UIControlStateNormal];
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // منع الضغط على نفس الزر في أقل من ثانيتين (لمنع التكرار العشوائي)
    if ([buttonTitle isEqualToString:lastTappedButton] && (currentTime - lastTapTime) < 2.0) {
        return;
    }
    
    lastTappedButton = buttonTitle;
    lastTapTime = currentTime;
    
    [button sendActionsForControlEvents:UIControlEventTouchDown];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    
    NSLog(@"[AutoEarn] تم الضغط على الزر: %@", buttonTitle);
}

// ---------------------------------------------------------
// اعتراض دورة حياة الـ View Controller
// ---------------------------------------------------------
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // التأكد من عدم وجود مؤقتات قديمة لتجنب التكرار
    if (fastTimer) {
        [fastTimer invalidate];
        fastTimer = nil;
    }
    if (restartTimer) {
        [restartTimer invalidate];
        restartTimer = nil;
    }
    
    // المؤقت السريع: يفحص الشاشة كل 3 ثوانٍ
    fastTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                 target:self
                                               selector:@selector(autoEarnTimerTick:)
                                               userInfo:nil
                                                repeats:YES];
    
    // مؤقت إعادة التشغيل: يضمن استمرار العمل اللانهائي حتى لو توقف المؤقت الأول
    restartTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                    target:self
                                                  selector:@selector(restartFastTimer:)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    // لا نوقف المؤقتات هنا لكي تستمر في العمل عند الانتقال بين الشاشات
}

// دالة إعادة تشغيل المؤقت السريع (لضمان التنفيذ اللانهائي)
- (void)restartFastTimer:(NSTimer *)timer {
    NSLog(@"[AutoEarn] إعادة تشغيل المؤقت السريع لضمان الاستمرارية...");
    
    if (fastTimer) {
        [fastTimer invalidate];
    }
    
    fastTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                 target:self
                                               selector:@selector(autoEarnTimerTick:)
                                               userInfo:nil
                                                repeats:YES];
}

// دالة المؤقت الرئيسية (منطق التنفيذ)
- (void)autoEarnTimerTick:(NSTimer *)timer {
    UIView *currentView = self.view;
    if (!currentView) return;
    
    // =========================================================
    // الأولوية الأولى: البحث عن حاوية "Watch videos" ثم الضغط على زر "Earn" بداخلها
    // =========================================================
    UIView *watchVideosContainer = findViewWithText(currentView, @"Watch videos");
    
    if (watchVideosContainer) {
        UIView *parentContainer = watchVideosContainer.superview;
        
        UIButton *earnBtn = findButtonWithText(parentContainer, @"Earn");
        
        if (!earnBtn && parentContainer.superview) {
            earnBtn = findButtonWithText(parentContainer.superview, @"Earn");
        }
        
        if (earnBtn) {
            simulateButtonTap(earnBtn);
            return;
        }
    }
    
    // =========================================================
    // الأولوية الثانية: البحث عن زر "Watch Videos" (داخل صفحة الفيديوهات)
    // =========================================================
    UIButton *watchVideosBtn = findButtonWithText(currentView, @"Watch Videos");
    if (watchVideosBtn) {
        simulateButtonTap(watchVideosBtn);
        return;
    }
    
    // =========================================================
    // الأولوية الثالثة: البحث عن زر "Other ways to earn"
    // =========================================================
    UIButton *otherWaysBtn = findButtonWithText(currentView, @"Other ways to earn");
    if (otherWaysBtn) {
        simulateButtonTap(otherWaysBtn);
        return;
    }
}

%end
