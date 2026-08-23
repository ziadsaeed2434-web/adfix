#import <Foundation/Foundation.h>

// ==========================================
// 1. شبكة IronSource / LevelPlay
// ==========================================
%hook ISRewardedAd

- (BOOL)isReadyToShow {
    return YES;
}

- (void)showFromViewController:(id)arg1 {
    %orig(arg1);
    if ([self respondsToSelector:@selector(adInstanceDidReward)]) {
        [self adInstanceDidReward];
    }
}

%end


// ==========================================
// 2. شبكة Google AdMob (GAD)
// ==========================================
%hook GADRewardedAdBridge

- (void)showFromViewController:(id)arg1 userEarnedRewardHandler:(id)arg2 {
    void (^rewardHandler)(void) = arg2;
    if (rewardHandler) {
        rewardHandler();
    }
    %orig(arg1, arg2);
}

%end


// ==========================================
// 3. شبكة Unity Ads (UADS)
// ==========================================
%hook UADSRewardedAd

- (BOOL)isReady {
    return YES;
}

- (void)show:(id)arg1 delegate:(id)arg2 {
    %orig(arg1, arg2);
    id delegate = arg2;
    if (delegate && [delegate respondsToSelector:@selector(unityAdsDidFinish:withFinishState:)]) {
        [delegate unityAdsDidFinish:nil withFinishState:1];
    }
}

%end


// ==========================================
// 4. شبكة Vungle / Liftoff
// ==========================================
%hook VungleAdsSDKVungleRewarded

- (void)presentWith:(id)arg1 {
    %orig(arg1);
    id delegate = [self delegate];
    if (delegate && [delegate respondsToSelector:@selector(vungleRewardedAdDidReward:)]) {
        [delegate vungleRewardedAdDidReward:self];
    }
}

%end


// ==========================================
// 5. شبكة Chartboost (CHB)
// ==========================================
%hook CHBRewarded

- (BOOL)isCached {
    return YES;
}

- (void)showFromViewController:(id)arg1 {
    %orig(arg1);
    id delegate = [self delegate];
    if (delegate && [delegate respondsToSelector:@selector(didRewardWithAdID:reward:)]) {
        [delegate didRewardWithAdID:nil reward:10];
    }
}

%end


// ==========================================
// 6. شبكة Mintegral (MTG)
// ==========================================
%hook MTGRewardAdManager

- (BOOL)isVideoReadyToPlayWithPlacementId:(id)arg1 unitId:(id)arg2 {
    return YES; // إجبار الفيديو على أن يكون جاهزاً دائماً
}

- (void)showVideoWithPlacementId:(id)arg1 unitId:(id)arg2 userId:(id)arg3 delegate:(id)arg4 viewController:(id)arg5 {
    %orig(arg1, arg2, arg3, arg4, arg5);
    
    // محاكاة منح المكافأة عبر الـ Delegate الخاص بـ Mintegral
    id delegate = arg4;
    if (delegate && [delegate respondsToSelector:@selector(onVideoAdRewarded:)]) {
        [delegate onVideoAdRewarded:arg1];
    }
}

%end
