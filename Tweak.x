// Tweak.x - إصدار آمن 100% (هوك UIDevice فقط)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// =====================================================================
// قوائم الأسماء والموديلات المزيفة (ثوابت C arrays)
// =====================================================================
static NSString * const deviceNames[] = {
    @"iPhone 11", @"iPhone 12", @"iPhone 13", @"iPad Pro", @"iPad Air"
};
static const NSUInteger deviceNamesCount = sizeof(deviceNames)/sizeof(deviceNames[0]);

static NSString * const models[] = {
    @"iPhone13,2", @"iPhone14,3", @"iPad13,4"
};
static const NSUInteger modelsCount = sizeof(models)/sizeof(models[0]);

// =====================================================================
// بذرة العشوائية (تُولَّد مرة واحدة عند تحميل الت tweak)
// =====================================================================
static NSUInteger sessionSeed = 0;

static void generateSessionSeed(void) {
    sessionSeed = (NSUInteger)([[NSDate date] timeIntervalSince1970] * 1000) ^ getpid();
}

static NSUInteger randomInRange(NSUInteger min, NSUInteger max) {
    if (sessionSeed == 0) generateSessionSeed();
    // نستخدم srand مع قيمة متغيرة لإضافة تنوع إضافي
    srand((unsigned)(sessionSeed + rand()));
    return min + arc4random_uniform((uint32_t)(max - min + 1));
}

// =====================================================================
// هوك UIDevice (آمن تمامًا)
// =====================================================================
%hook UIDevice
- (NSString *)name {
    return deviceNames[randomInRange(0, deviceNamesCount - 1)];
}
- (NSString *)systemVersion {
    NSUInteger major = randomInRange(14, 16);
    NSUInteger minor = randomInRange(0, 5);
    return [NSString stringWithFormat:@"%lu.%lu", (unsigned long)major, (unsigned long)minor];
}
- (NSString *)model {
    return models[randomInRange(0, modelsCount - 1)];
}
%end

// =====================================================================
// التهيئة المبكرة (لا تفعل شيئًا سوى توليد البذرة وتفعيل الهوك)
// =====================================================================
%ctor {
    generateSessionSeed();
    %init; // تفعيل هوك UIDevice
}
