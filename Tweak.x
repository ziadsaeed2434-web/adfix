#import <UIKit/UIKit.h>

static void findAndClickTargetButtons(UIView *view) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            // مطابقة دقيقة تماماً للنصوص التي طلبتها
            if (title && ([title isEqualToString:@"Watch Videos"] || [title isEqualToString:@"Other ways to earn"])) {
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                [button sendActionsForControlEvents:UIControlEventTouchDown];
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
        }
        
        if (subview.subviews.count > 0) {
            findAndClickTargetButtons(subview);
        }
    }
}

%hook UIView

- (void)layoutSubviews {
    %orig;
    findAndClickTargetButtons(self);
}

%end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            UIWindow *keyWindow = nil;
            NSArray *windows = [UIApplication sharedApplication].windows;
            for (UIWindow *window in windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (!keyWindow && windows.count > 0) {
                keyWindow = windows[0];
            }
            
            if (keyWindow) {
                findAndClickTargetButtons(keyWindow);
            }
        }];
    });
}
