#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static UITextView *fileLogView = nil;

void showFileLog(NSString *logText) {
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
            UIView *overlay = [keyWindow viewWithTag:777888];
            if (!overlay) {
                overlay = [[UIView alloc] initWithFrame:CGRectMake(10, 40, keyWindow.bounds.size.width - 20, 260)];
                overlay.tag = 777888;
                overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
                overlay.layer.cornerRadius = 8;
                
                fileLogView = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, overlay.bounds.size.width - 10, overlay.bounds.size.height - 10)];
                fileLogView.backgroundColor = [UIColor clearColor];
                fileLogView.textColor = [UIColor greenColor];
                fileLogView.font = [UIFont fontWithName:@"Courier" size:9];
                fileLogView.editable = NO;
                fileLogView.text = @"[+] Full Content Monitor Started...\n";
                
                [overlay addSubview:fileLogView];
                [keyWindow addSubview:overlay];
            }
            
            if (fileLogView) {
                NSString *oldText = fileLogView.text;
                fileLogView.text = [NSString stringWithFormat:@"%@\n--------------------\n%@", logText, oldText];
            }
        }
    });
}

// دالة مساعدة لتحويل NSData إلى نص أو وصف دقيق للمحتوى
NSString* parseDataContent(NSData *data) {
    if (!data) return @"<Nil Data>";
    
    // محاولة تحويله إلى نص UTF-8 مباشر
    NSString *textStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (textStr && textStr.length > 0) {
        return [NSString stringWithFormat:@"[Text Content]:\n%@", textStr];
    }
    
    // إذا كان محتوى مشفر أو باينري، نحاول قراءته كـ plist أو JSON محلي إن أمكن
    NSError *error = nil;
    id plistObj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    if (plistObj) {
        return [NSString stringWithFormat:@"[Plist/Dict Content]:\n%@", plistObj];
    }
    
    // كحل أخير، نعرض حجم البيانات وهكساديكسمل مبسط
    return [NSString stringWithFormat:@"<Binary Data - Size: %lu bytes>", (unsigned long)data.length];
}

%hook NSData

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile error:(NSError **)error {
    BOOL result = %orig;
    if ([path containsString:@"userInfo.data"]) {
        NSString *contentDesc = parseDataContent(self);
        NSString *log = [NSString stringWithFormat:@"[WRITE] Path: %@\n%@", path, contentDesc];
        showFileLog(log);
    }
    return result;
}

- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error {
    BOOL result = %orig;
    if ([path containsString:@"userInfo.data"]) {
        NSString *contentDesc = parseDataContent(self);
        NSString *log = [NSString stringWithFormat:@"[WRITE OPT] Path: %@\n%@", path, contentDesc];
        showFileLog(log);
    }
    return result;
}

+ (NSData *)dataWithContentsOfFile:(NSString *)path {
    NSData *result = %orig;
    if ([path containsString:@"userInfo.data"] && result) {
        NSString *contentDesc = parseDataContent(result);
        NSString *log = [NSString stringWithFormat:@"[READ] Path: %@\n%@", path, contentDesc];
        showFileLog(log);
    }
    return result;
}

%end
