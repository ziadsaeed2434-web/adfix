#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define MAX_PRELOADED_ADS_PER_ID 15

static NSMutableDictionary *adQueuesMap = nil;
static NSMutableDictionary *activeLoadersMap = nil;
static NSMutableDictionary *isFetchingMap = nil;

__attribute__((constructor)) static void initializeFastReadyPools() {
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

// دالة سريعة جداً لتعبئة الطابور خلفياً وبدون استهلاك موارد الواجهة
static void FastBackgroundRefill(NSString *adUnitID, id request) {
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
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        FastBackgroundRefill(adUnitID, request);
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

// إبقاء الإعلانات جاهزة ومخزنة بطلبك اليدوي السريع
+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id, NSError *))arg3 {
    
    if (adUnitID) {
        NSMutableArray *queue = adQueuesMap[adUnitID];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            adQueuesMap[adUnitID] = queue;
        }
        
        if (queue.count < MAX_PRELOADED_ADS_PER_ID) {
            %orig(adUnitID, request, ^(id ad, NSError *error) {
                if (ad && !error) {
                    [queue addObject:ad];
                }
                FastBackgroundRefill(adUnitID, request);
                
                if (arg3) {
                    arg3(ad, error);
                }
            });
            return;
        }
    }
    
    %orig;
}

%end
