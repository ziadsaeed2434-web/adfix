#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// متغير عام للنافذة وعرض المسارات
static UITextView *logTextView = nil;

void showLogWindow(NSString *logMessage) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow) {
            UIView *overlayView = [keyWindow viewWithTag:888877];
            if (!overlayView) {
                overlayView = [[UIView alloc] initWithFrame:CGRectMake(10, 50, keyWindow.bounds.size.width - 20, 200)];
                overlayView.tag = 888877;
                overlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
                overlayView.layer.cornerRadius = 10;
                
                logTextView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlayView.bounds.size.width - 10, overlayView.bounds.size.height - 10)];
                logTextView.backgroundColor = [UIColor clearColor];
                logTextView.textColor = [UIColor greenColor];
                logTextView.font = [UIFont fontWithName:@"Courier" size:11];
                logTextView.editable = NO;
                logTextView.text = @"[+] File Monitor Started...\n";
                
                [overlayView addSubview:logTextView];
                [keyWindow addSubview:overlayView];
            }
            
            if (logTextView) {
                NSString *currentText = logTextView.text;
                logTextView.text = [NSString stringWithFormat:@"%@\n%@", logMessage, currentText];
            }
        }
    });
}

// مراقبة كتابة البيانات إلى الملفات (NSData writeToFile)
%hook NSData

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile error:(NSError **)error {
    BOOL result = %orig;
    if (result) {
        NSString *log = [NSString stringWithFormat:@"[Data File]: %@", path];
        showLogWindow(log);
    }
    return result;
}

- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error {
    BOOL result = %orig;
    if (result) {
        NSString *log = [NSString stringWithFormat:@"[Data Opt File]: %@", path];
        showLogWindow(log);
    }
    return result;
}

%end

// مراقبة كتابة القواميس والمصفوفات (NSDictionary / NSArray writeToFile)
%hook NSDictionary

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    BOOL result = %orig;
    if (result) {
        NSString *log = [NSString stringWithFormat:@"[Plist Dict]: %@", path];
        showLogWindow(log);
    }
    return result;
}

%end

%hook NSMutableDictionary

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    BOOL result = %orig;
    if (result) {
        NSString *log = [NSString stringWithFormat:@"[MutableDict]: %@", path];
        showLogWindow(log);
    }
    return result;
}

%end
