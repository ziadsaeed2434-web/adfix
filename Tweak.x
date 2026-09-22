#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// متغيرات عامة
static NSTimer *mainTimer = nil;
static NSString *lastTappedButton = nil;
static NSTimeInterval lastTapTime = 0;

// 1. دالة مساعدة للبحث عن أي UIView يحتوي على نص معين
UIView* findViewWithText(UIView *parentView, NSString *searchText) {
    if (!parentView) return nil;
    
    @try {
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
    } @catch (NSException *exception) {
        // تجاهل أي استثناء لتجنب الكراش
    }
    return nil;
}

// 2. دالة مساعدة للبحث عن زر يحتوي على نص معين
UIButton* findButtonWithText(UIView *parentView, NSString *searchText) {
    if (!parentView) return nil;
    
    @try {
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
    } @catch (NSException *exception) {
        // تجاهل أي استثناء
    }
    return nil;
}

// 3. دالة محاكاة الضغط
void simulateButtonTap(UIButton *button) {
    if (!button || !button.enabled || button.hidden || button.alpha == 0) return;
    
    @try {
        NSString *buttonTitle = [button titleForState:UIControlStateNormal];
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        
        if ([buttonTitle isEqualToString:lastTappedButton] && (currentTime - lastTapTime) < 2.0) {
            return;
        }
        
        lastTappedButton = buttonTitle;
        lastTapTime = currentTime;
        
        [button sendActionsForControlEvents:UIControlEventTouchDown];
        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        
        NSLog(@"[AutoEarn] تم الضغط على الزر: %@", buttonTitle);
    } @catch (NSException *exception) {
        // تجاهل
    }
}

// 4. دالة الحصول على الواجهة الحالية (أهم جزء لمنع الكراش)
UIView* getCurrentActiveView() {
    UIWindow *keyWindow = nil;
    
    // البحث عن النافذة النشطة (يدعم iOS 13+ و iOS القديم)
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    return keyWindow;
}

// 5. دالة المؤقت الرئيسية (منطق التنفيذ)
void autoEarnTimerTick() {
    // التأكد من أننا في الخيط الرئيسي (Main Thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIView *currentView = getCurrentActiveView();
            if (!currentView) return;
            
            // =========================================================
            // الأولوية الأولى: زر "Earn" الخاص بـ "Watch videos"
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
            // الأولوية الثانية: زر "Watch Videos"
            // =========================================================
            UIButton *watchVideosBtn = findButtonWithText(currentView, @"Watch Videos");
            if (watchVideosBtn) {
                simulateButtonTap(watchVideosBtn);
                return;
            }
            
            // =========================================================
            // الأولوية الثالثة: زر "Other ways to earn"
            // =========================================================
            UIButton *otherWaysBtn = findButtonWithText(currentView, @"Other ways to earn");
            if (otherWaysBtn) {
                simulateButtonTap(otherWaysBtn);
                return;
            }
        } @catch (NSException *exception) {
            NSLog(@"[AutoEarn] استثناء: %@", exception.reason);
        }
    });
}

// ---------------------------------------------------------
// نقطة البداية: تشغيل المؤقت مرة واحدة فقط عند تحميل التويك
// ---------------------------------------------------------
%ctor {
    // انتظر 5 ثوانٍ بعد تشغيل التطبيق قبل بدء الأتمتة (لضمان استقرار التطبيق)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AutoEarn] بدء تشغيل الأتمتة...");
        
        // إنشاء المؤقت الرئيسي كل 5 ثوانٍ
        mainTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                     target:[NSBlockOperation blockOperationWithBlock:^{}]
                                                   selector:nil
                                                   userInfo:nil
                                                    repeats:NO];
        
        // استخدام NSTimer مع Block لتجنب الحاجة إلى Target
        mainTimer = [NSTimer timerWithTimeInterval:5.0
                                           repeats:YES
                                             block:^(NSTimer * _Nonnull timer) {
            autoEarnTimerTick();
        }];
        
        // إضافة المؤقت إلى الـ RunLoop الرئيسي
        [[NSRunLoop mainRunLoop] addTimer:mainTimer forMode:NSRunLoopCommonModes];
    });
}
