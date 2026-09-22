#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSTimer *mainTimer = nil;
static NSString *lastTappedButton = nil;
static NSTimeInterval lastTapTime = 0;

// 1. البحث عن أي UIView يحتوي على نص معين
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
            if (foundView) return foundView;
        }
    } @catch (NSException *exception) {}
    return nil;
}

// 2. البحث عن زر يحتوي على نص معين
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
            if (foundButton) return foundButton;
        }
    } @catch (NSException *exception) {}
    return nil;
}

// 3. محاكاة الضغط
void simulateButtonTap(UIButton *button) {
    if (!button || !button.enabled || button.hidden || button.alpha == 0) return;
    @try {
        NSString *buttonTitle = [button titleForState:UIControlStateNormal];
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        if ([buttonTitle isEqualToString:lastTappedButton] && (currentTime - lastTapTime) < 2.0) return;
        lastTappedButton = buttonTitle;
        lastTapTime = currentTime;
        [button sendActionsForControlEvents:UIControlEventTouchDown];
        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[AutoEarn] تم الضغط على الزر: %@", buttonTitle);
    } @catch (NSException *exception) {}
}

// 4. الحصول على النافذة النشطة
UIView* getCurrentActiveView() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
                }
            }
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
    return keyWindow;
}

// 5. منطق التنفيذ الرئيسي
void autoEarnTimerTick() {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIView *currentView = getCurrentActiveView();
            if (!currentView) return;

            // الأولوية 1: زر Earn الخاص بـ Watch videos
            UIView *watchVideosContainer = findViewWithText(currentView, @"Watch videos");
            if (watchVideosContainer) {
                UIView *parentContainer = watchVideosContainer.superview;
                UIButton *earnBtn = findButtonWithText(parentContainer, @"Earn");
                if (!earnBtn && parentContainer.superview) {
                    earnBtn = findButtonWithText(parentContainer.superview, @"Earn");
                }
                if (earnBtn) { simulateButtonTap(earnBtn); return; }
            }

            // الأولوية 2: زر Watch Videos
            UIButton *watchVideosBtn = findButtonWithText(currentView, @"Watch Videos");
            if (watchVideosBtn) { simulateButtonTap(watchVideosBtn); return; }

            // الأولوية 3: زر Other ways to earn
            UIButton *otherWaysBtn = findButtonWithText(currentView, @"Other ways to earn");
            if (otherWaysBtn) { simulateButtonTap(otherWaysBtn); return; }
        } @catch (NSException *exception) {
            NSLog(@"[AutoEarn] استثناء: %@", exception.reason);
        }
    });
}

// ---------------------------------------------------------
// نقطة البداية: تشغيل المؤقت مرة واحدة فقط
// ---------------------------------------------------------
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AutoEarn] بدء تشغيل الأتمتة...");

        // استخدام NSTimer مع Block (لا يحتاج selector ولا target)
        mainTimer = [NSTimer timerWithTimeInterval:5.0
                                           repeats:YES
                                             block:^(NSTimer * _Nonnull timer) {
            autoEarnTimerTick();
        }];

        [[NSRunLoop mainRunLoop] addTimer:mainTimer forMode:NSRunLoopCommonModes];
    });
}
