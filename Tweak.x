#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define MAX_PRELOADED_ADS_PER_ID 15

static NSMutableDictionary *adQueuesMap = nil;
static NSMutableDictionary *activeLoadersMap = nil;
static NSMutableDictionary *isFetchingMap = nil;

__attribute__((constructor)) static void initializeUltraFastPools() {
    adQueuesMap = [[NSMutableDictionary alloc] init];
    activeLoadersMap = [[NSMutableDictionary alloc] init];
    isFetchingMap = [[NSMutableDictionary alloc] init];
}

static NSString * GetAdUnitIDFromObject(id object) {
    if (!object) return nil;
    if ([object respondsToSelector:@selector(adUnitID)]) {
        return [object performSelector:@selector(adUnitID)];
    }
    Ivar ivar = class_getInstanceVariable(object_getClass(object), "_adUnitID");
    if (ivar) {
        id value = object_getIvar(object, ivar);
        if ([value isKindOfClass:[NSString class]]) {
            return (NSString *)value;
        }
    }
    return nil;
}

// دالة آمنة تماماً تستخدم Runtime لاستدعاء دالة التحميل بدون أي رموز ربط مفقودة
static void UltraFastRefillQueue(NSString *adUnitID, id request) {
    if (!adUnitID) return;
    
    NSMutableArray *queue = adQueuesMap[adUnitID];
    if (!queue) {
        queue = [[NSMutableArray alloc] init];
        adQueuesMap[adUnitID] = queue;
    }
    
    if (queue.count >= MAX_PRELOADED_ADS_PER_ID) return;
    if ([isFetchingMap[adUnitID] boolValue]) return;
    isFetchingMap[adUnitID] = @YES;
    
    Class gadClass = NSClassFromString(@"GADRewardedAd");
    if (gadClass) {
        SEL selector = NSSelectorFromString(@"loadWithAdUnitID:request:completionHandler:");
        if ([gadClass respondsToSelector:selector]) {
            // استخدام IMP invocation أو تنفيذ الكتلة برمجياً لتجنب مشاكل الـ Linker
            NSMethodSignature *signature = [gadClass methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:gadClass];
            [invocation setSelector:selector];
            [invocation setArgument:&adUnitID atIndex:2];
            [invocation setArgument:&request atIndex:3];
            
            void (^completionBlock)(id, NSError *) = ^(id ad, NSError *error) {
                isFetchingMap[adUnitID] = @NO;
                if (ad && !error) {
                    NSMutableArray *currentQueue = adQueuesMap[adUnitID];
                    if (currentQueue && currentQueue.count < MAX_PRELOADED_ADS_PER_ID) {
                        [currentQueue addObject:ad];
                    }
                }
                
                NSMutableArray *checkQueue = adQueuesMap[adUnitID];
                if (checkQueue && checkQueue.count < MAX_PRELOADED_ADS_PER_ID) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        UltraFastRefillQueue(adUnitID, request);
                    });
                }
            };
            [invocation setArgument:&completionBlock atIndex:4];
            [invocation invoke];
            return;
        }
    }
    isFetchingMap[adUnitID] = @NO;
}

%hook GADAdLoader

- (void)loadRequest:(id)request {
    NSString *adUnitID = GetAdUnitIDFromObject(self);
    if (adUnitID) {
        activeLoadersMap[adUnitID] = self;
    }
    %orig;
}

- (void)receivePublicAd:(id)ad {
    NSString *adUnitID = GetAdUnitIDFromObject(self);
    if (ad && adUnitID) {
        NSMutableArray *queue = adQueuesMap[adUnitID];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            adQueuesMap[adUnitID] = queue;
        }
        if (queue.count < MAX_PRELOADED_ADS_PER_ID) {
            [queue addObject:ad];
        }
    }
    %orig;
}

%end

%hook GADRewardedAd

+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id, NSError *))arg3 {
    
    void (^localHandler)(id, NSError *) = [arg3 copy];
    
    if (adUnitID) {
        NSMutableArray *queue = adQueuesMap[adUnitID];
        
        if (queue && queue.count > 0) {
            id cachedAd = [queue firstObject];
            [queue removeObjectAtIndex:0];
            
            if (localHandler) {
                localHandler(cachedAd, nil);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UltraFastRefillQueue(adUnitID, request);
            });
            return;
        }
    }
    
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (ad && !error && adUnitID) {
            NSMutableArray *queue = adQueuesMap[adUnitID];
            if (!queue) {
                queue = [[NSMutableArray alloc] init];
                adQueuesMap[adUnitID] = queue;
            }
            [queue addObject:ad];
            UltraFastRefillQueue(adUnitID, request);
        }
        if (localHandler) {
            localHandler(ad, error);
        }
    });
}

%end
