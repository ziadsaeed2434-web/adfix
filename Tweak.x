#import <UIKit/UIKit.h>

%hook YMM__YX_SSJailbreakCheck

+ (int)filesExistCheck {
    return 0;
}

+ (int)cydiaCheck {
    return 0;
}

+ (int)inaccessibleFilesCheck {
    return 0;
}

+ (int)jailbroken {
    return 0;
}

+ (int)plistCheck {
    return 0;
}

+ (int)symbolicLinkCheck {
    return 0;
}

+ (int)urlCheck {
    return 0;
}

+ (id)runningProcesses {
    return nil;
}

%end
