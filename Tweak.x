#import <Foundation/Foundation.h>

static void overrideDefaults(NSUserDefaults *defaults) {
    if (!defaults) return;
    
    // تصفير أو ضبط القيم التي تتحكم في تكرار الجلسات والإعلانات والتتبع
    [defaults setBool:NO  forKey:@"io.appmetrica.sdk.app.was.in.background"];
    [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
    [defaults setInteger:0 forKey:@"AppsFlyerLaunchKey"];
    [defaults setInteger:0 forKey:@"AppsFlyerCounter"];
    [defaults setInteger:0 forKey:@"ump_status"];
}

%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"io.appmetrica.sdk.app.was.in.background"]) {
        value = NO;
    }
    %orig(value, defaultName);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"AppsFlyerReinstallCounter"]) {
        value = 0;
    } else if ([defaultName isEqualToString:@"AppsFlyerLaunchKey"]) {
        value = 0;
    } else if ([defaultName isEqualToString:@"AppsFlyerCounter"]) {
        value = 0;
    } else if ([defaultName isEqualToString:@"ump_status"]) {
        value = 0;
    }
    %orig(value, defaultName);
}

- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"io.appmetrica.sdk.app.was.in.background"]) return NO;
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"AppsFlyerReinstallCounter"]) return 0;
    if ([defaultName isEqualToString:@"AppsFlyerLaunchKey"]) return 0;
    if ([defaultName isEqualToString:@"AppsFlyerCounter"]) return 0;
    if ([defaultName isEqualToString:@"ump_status"]) return 0;
    return %orig;
}

%end

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        overrideDefaults(defaults);
        [defaults synchronize];
        
        NSLog(@"[AdEveryTime] Hooked NSUserDefaults and reset counters to force ads on every launch!");
    }
}
