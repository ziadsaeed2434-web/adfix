#import <Foundation/Foundation.h>

%hook NSDate

// 1. اعتراض دالة إنشاء تاريخ جديد بالوقت الحالي
+ (id)date {
    // جلب التاريخ الحالي الحقيقي وإضافة 300 ثانية (5 دقائق) إليه
    NSDate *realDate = %orig;
    return [realDate dateByAddingTimeInterval:300]; // تقديم الوقت 5 دقائق
}

// 2. اعتراض دالة الوقت الحالي بصيغة التاوستامب (timeIntervalSince1970)
- (NSTimeInterval)timeIntervalSince1970 {
    // إضافة 300 ثانية (5 دقائق) إلى الوقت الحالي ليظن التطبيق أن 5 دقائق إضافية قد مرت
    return %orig + 300;
}

%end
