#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static UITextView *universalLogView = nil;

void showUniversalLog(NSString *logText) {
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
            UIView *overlay = [keyWindow viewWithTag:999888];
            if (!overlay) {
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 35, keyWindow.bounds.size.width - 20, 280)];
                overlay.tag = 999888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.92];
                overlay.layer.cornerRadius = 8;
                
                universalLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                universalLogView.backgroundColor = [UIColor clearColor];
                universalLogView.textColor = [UIColor orangeColor];
                universalLogView.font = [UIFont fontWithName:@"Courier" size:9];
                universalLogView.editable = NO;
                universalLogView.text = @"[+] Ultimate Comprehensive Monitor Active...\n";
                
                [overlay addSubview:universalLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (universalLogView) {
                NSString *oldText = universalLogView.text;
                universalLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// 1. مراقبة التخزين المحلي السريع NSUserDefaults
%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    %orig;
    NSString *log = [NSString stringWithFormat:@"[Defaults Object] Key: %@ = %@", defaultName, value];
    showUniversalLog(log);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    %orig;
    NSString *log = [NSString stringWithFormat:@"[Defaults Integer] Key: %@ = %ld", defaultName, (long)value];
    showUniversalLog(log);
}

%end

// 2. مراقبة كتابة أي ملف محلياً في التطبيق
%hook NSData

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile error:(NSError **)error {
    BOOL result = %orig;
    if (result) {
        NSString *contentStr = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
        NSString *fileName = [path lastPathComponent];
        NSString *log = [NSString stringWithFormat:@"[File Write] File: %@\nPath: %@\nContent: %@", fileName, path, contentStr ? contentStr : [NSString stringWithFormat:@"<Binary Size: %lu>", (unsigned long)self.length]];
        showUniversalLog(log);
    }
    return result;
}

- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error {
    BOOL result = %orig;
    if (result) {
        NSString *contentStr = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
        NSString *fileName = [path lastPathComponent];
        NSString *log = [NSString stringWithFormat:@"[File Write Opt] File: %@\nContent: %@", fileName, contentStr ? contentStr : [NSString stringWithFormat:@"<Binary Size: %lu>", (unsigned long)self.length]];
        showUniversalLog(log);
    }
    return result;
}

%end

// 3. مراقبة تحليل الـ JSON محلياً
%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    id result = %orig;
    if (result && [result isKindOfClass:[NSDictionary class]]) {
        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (jsonStr && (([jsonStr containsString:@"point"] || [jsonStr containsString:@"score"] || [jsonStr containsString:@"coin"]))) {
            NSString *log = [NSString stringWithFormat:@"[JSON Points Intercept]:\n%@", jsonStr];
            showUniversalLog(log);
        }
    }
    return result;
}

%end
