#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// تسريع إعلانات الفيديو فقط عبر تتبع رابط المصدر
%hook AVPlayer

- (void)play {
    %orig;
    
    AVPlayerItem *currentItem = self.currentItem;
    if (currentItem) {
        AVAsset *asset = currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSString *videoURLString = [((AVURLAsset *)asset).URL absoluteString];
            
            // التحقق مما إذا كان الفيديو ينتمي لشبكة إعلانات Unity أو روابط دعائية
            if ([videoURLString containsString:@"iads.unity3d.com"] || 
                [videoURLString containsString:@"unityads"] || 
                [videoURLString containsString:@"ads"] || 
                [videoURLString containsString:@"reward"] ||
                [videoURLString containsString:@"promo"]) {
                
                // تسريع الإعلان فقط إلى 8 أضعاف سرعته
                self.rate = 8.0;
            }
        }
    }
}

- (void)setRate:(float)rate {
    AVPlayerItem *currentItem = self.currentItem;
    if (currentItem) {
        AVAsset *asset = currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSString *videoURLString = [((AVURLAsset *)asset).URL absoluteString];
            
            if ([videoURLString containsString:@"iads.unity3d.com"] || 
                [videoURLString containsString:@"unityads"] || 
                [videoURLString containsString:@"ads"] || 
                [videoURLString containsString:@"reward"]) {
                if (rate < 8.0) {
                    %orig(8.0);
                    return;
                }
            }
        }
    }
    %orig(rate);
}

%end
