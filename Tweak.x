#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;
static NSString *currentISPType = @"غير معروف"; // "Residential" أو "Datacenter"

// المعرفات الوهمية
static NSUUID *fakeVendorID = nil;
static NSUUID *fakeAdvertisingID = nil;

// ============================================================
// MARK: - دوال مساعدة
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// ============================================================
// MARK: - تعريف النطاقات السكنية الأمريكية (Residential Only)
// ============================================================

// بنية لتخزين نطاق IP (CIDR) مع تصنيف "سكني"
typedef struct {
    char *name;
    int prefix;      // البايت الأول
    int secondStart;
    int secondEnd;
    int thirdStart;
    int thirdEnd;
    bool residential; // هل هذا النطاق سكني بحت؟
} ISPBlock;

// هذه النطاقات تم جمعها من سجلات ARIN للمزودين السكنيين الكبار
static ISPBlock ispBlocks[] = {
    // ========== AT&T (Residential) ==========
    {.name = "AT&T", .prefix = 12, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 32, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 99, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 107, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 108, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 135, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 136, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 137, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 138, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 139, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 140, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 141, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 142, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 143, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 144, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 145, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 146, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 147, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 148, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 149, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 150, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 151, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 152, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 153, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 154, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 155, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 156, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 157, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 158, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 159, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 160, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 161, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 162, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 163, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 164, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 165, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 166, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 167, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 168, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 169, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 170, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 171, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 172, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 173, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 174, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 175, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 176, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 177, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 178, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 179, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 180, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 181, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 182, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 183, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 184, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 185, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 186, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 187, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 188, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 189, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 190, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 191, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 192, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 193, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 194, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 195, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 196, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 197, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 198, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "AT&T", .prefix = 199, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== Comcast / Xfinity (Residential) ==========
    {.name = "Comcast", .prefix = 23, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 24, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 50, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 67, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 68, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 69, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 71, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 73, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 75, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 76, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 96, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 97, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 98, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 99, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 100, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 104, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 108, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 128, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 129, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 130, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 131, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 132, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 133, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 134, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 135, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 136, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 137, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 138, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 139, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 140, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 141, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 142, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 143, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 144, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 145, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 146, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 147, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 148, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 149, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 150, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 151, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 152, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 153, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 154, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 155, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 156, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 157, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 158, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 159, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 160, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 161, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 162, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 163, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 164, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 165, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 166, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 167, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 168, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 169, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Comcast", .prefix = 170, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== Google Fiber (Residential) ==========
    {.name = "Google Fiber", .prefix = 104, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Google Fiber", .prefix = 108, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Google Fiber", .prefix = 136, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Google Fiber", .prefix = 137, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Google Fiber", .prefix = 138, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== Spectrum / Charter (Residential) ==========
    {.name = "Spectrum", .prefix = 47, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 62, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 66, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 67, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 68, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 69, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 71, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 73, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 75, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 76, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 97, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 98, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 99, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 100, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 104, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 107, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 108, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 128, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 129, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 130, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 131, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 132, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 133, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 134, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Spectrum", .prefix = 135, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== Cox Communications (Residential) ==========
    {.name = "Cox", .prefix = 24, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 32, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 50, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 51, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 68, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 69, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 71, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 73, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 75, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 76, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 98, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Cox", .prefix = 99, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== T-Mobile Home Internet (Residential 5G) ==========
    {.name = "T-Mobile", .prefix = 23, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 44, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 64, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 65, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 66, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 67, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 68, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 69, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 71, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 73, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 75, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "T-Mobile", .prefix = 76, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    // ========== Verizon (Residential) ==========
    {.name = "Verizon", .prefix = 23, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 24, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 25, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 26, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 27, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 28, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 29, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 30, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 32, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 33, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 34, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 35, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 36, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 37, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 38, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 39, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 40, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 41, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 42, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 43, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 44, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 45, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 46, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 47, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 48, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 49, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 50, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 51, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 52, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 53, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 54, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 55, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 56, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 57, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 58, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 59, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 60, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 61, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 62, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 63, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 64, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 65, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 66, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 67, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 68, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 69, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 70, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 71, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 72, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 73, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 74, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 75, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
    {.name = "Verizon", .prefix = 76, .secondStart = 0, .secondEnd = 255, .thirdStart = 0, .thirdEnd = 255, .residential = true},
};

// ============================================================
// MARK: - التحقق من نوع الـ IP (Residential vs Datacenter)
// ============================================================

// دالة للتحقق من IP باستخدام خدمة خارجية (ipinfo.io)
// تُرجع YES إذا كان IP سكنياً، NO إذا كان مركز بيانات أو غير معروف
BOOL verifyResidentialIP(NSString *ip) {
    if (!ip || ip.length == 0) return NO;
    
    // استخدام ipinfo.io للتأكد من نوع الـ IP
    NSString *urlString = [NSString stringWithFormat:@"https://ipinfo.io/%@/json", ip];
    NSURL *url = [NSURL URLWithString:urlString];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return NO;
    
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !json) return NO;
    
    // التحقق من حقل "org" لمعرفة المزود
    NSString *org = json[@"org"];
    if (org) {
        // إذا كان org يحتوي على "isp" أو "residential" أو اسم مزود سكني
        NSArray *residentialKeywords = @[@"Residential", @"ISP", @"Broadband", @"Cable", @"Fiber", @"DSL", @"5G"];
        for (NSString *keyword in residentialKeywords) {
            if ([org rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return YES;
            }
        }
        // إذا كان يحتوي على "Hosting" أو "Datacenter" -> ليس سكنياً
        NSArray *datacenterKeywords = @[@"Hosting", @"Datacenter", @"Cloud", @"Server", @"Dedicated"];
        for (NSString *keyword in datacenterKeywords) {
            if ([org rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return NO;
            }
        }
        // إذا لم نعرف، نعتبره سكنياً (افتراضي)
        return YES;
    }
    
    return NO; // إذا لم نتمكن من التحقق، نعتبره غير صالح
}

// ============================================================
// MARK: - توليد IP مع التحقق من أنه سكني
// ============================================================

void generateSessionIP() {
    int totalBlocks = sizeof(ispBlocks) / sizeof(ISPBlock);
    int maxAttempts = 20; // عدد المحاولات للعثور على IP سكني
    BOOL found = NO;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
        int index = arc4random_uniform(totalBlocks);
        ISPBlock block = ispBlocks[index];
        
        // نتجاوز النطاقات التي ليست سكنية (نستخدم فقط residential = true)
        if (!block.residential) continue;
        
        int prefix = block.prefix;
        int second = block.secondStart + arc4random_uniform(block.secondEnd - block.secondStart + 1);
        int third = block.thirdStart + arc4random_uniform(block.thirdEnd - block.thirdStart + 1);
        int fourth = arc4random_uniform(256);
        
        // تجنب النطاقات الخاصة
        if (prefix == 127) continue;
        if (prefix == 10) continue;
        if (prefix == 192 && second == 168) continue;
        if (prefix == 172 && second >= 16 && second <= 31) continue;
        
        NSString *testIP = [NSString stringWithFormat:@"%d.%d.%d.%d", prefix, second, third, fourth];
        
        // التحقق من أن IP سكني (اختياري، يمكن تعطيله إذا كان بطيئاً)
        // نستخدم طلب HTTP إلى ipinfo.io (يمكن أن يكون بطيئاً، لكنه يضمن الجودة)
        // إذا كنت تريد تعطيل التحقق، علق السطر التالي:
        if (verifyResidentialIP(testIP)) {
            sessionFakeIP = testIP;
            currentISPType = [NSString stringWithFormat:@"%s (سكني)", block.name];
            NSLog(@"[Injector] 🌐 تم العثور على IP سكني صالح: %@ (%@)", sessionFakeIP, currentISPType);
            found = YES;
            break;
        } else {
            NSLog(@"[Injector] ⚠️ IP غير سكني: %@ - جاري المحاولة مرة أخرى...", testIP);
        }
    }
    
    if (!found) {
        // في حال فشل كل المحاولات، نستخدم IP عشوائي من القائمة (بدون تحقق)
        int index = arc4random_uniform(totalBlocks);
        ISPBlock block = ispBlocks[index];
        int prefix = block.prefix;
        int second = block.secondStart + arc4random_uniform(block.secondEnd - block.secondStart + 1);
        int third = block.thirdStart + arc4random_uniform(block.thirdEnd - block.thirdStart + 1);
        int fourth = arc4random_uniform(256);
        sessionFakeIP = [NSString stringWithFormat:@"%d.%d.%d.%d", prefix, second, third, fourth];
        currentISPType = [NSString stringWithFormat:@"%s (افتراضي)", block.name];
        NSLog(@"[Injector] ⚠️ لم نتمكن من العثور على IP سكني، نستخدم IP افتراضي: %@", sessionFakeIP);
    }
}

// ============================================================
// MARK: - باقي الدوال (بدون تغيير كبير)
// ============================================================

void generateFakeIdentifiers() {
    fakeVendorID = [NSUUID UUID];
    fakeAdvertisingID = [NSUUID UUID];
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (ip && ip.length > 0) {
            currentRealIP = ip;
        } else {
            currentRealIP = @"غير قادر على الجلب";
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 30) {
        path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    }
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 خرج عبر IP: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, lat, lon];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) {
            [networkLogs removeLastObject];
        }
    }
}

// ============================================================
// MARK: - دالة إعادة الضبط الكاملة
// ============================================================

void performFullReset() {
    NSLog(@"[Injector] 🔄 بدء إعادة الضبط الكاملة...");
    
    // 1. مسح الكوكيز والكاش
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // 2. مسح NSUserDefaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 3. مسح الملفات المحلية (Documents, Library)
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths firstObject];
    if (docPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:docPath error:nil]) {
            [fm removeItemAtPath:[docPath stringByAppendingPathComponent:item] error:nil];
        }
    }
    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libPath = [paths firstObject];
    if (libPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:libPath error:nil]) {
            if (![item isEqualToString:@"Preferences"] && ![item isEqualToString:@"Caches"]) {
                [fm removeItemAtPath:[libPath stringByAppendingPathComponent:item] error:nil];
            }
        }
        NSString *cachePath = [libPath stringByAppendingPathComponent:@"Caches"];
        for (NSString *item in [fm contentsOfDirectoryAtPath:cachePath error:nil]) {
            [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:item] error:nil];
        }
    }
    
    // 4. مسح بيانات WebKit
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                               modifiedSince:[NSDate distantPast]
                                           completionHandler:^{
        NSLog(@"[Injector] 🧹 WebKit مسح.");
    }];
    
    // 5. تجديد الموقع والـ IP والمعرفات
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    
    // 6. مسح سجل الطلبات
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
    
    NSLog(@"[Injector] ✅ اكتملت إعادة الضبط. IP الحالي: %@ (نوع: %@)", sessionFakeIP, currentISPType);
}

// ============================================================
// MARK: - واجهة عرض التفاصيل (مع إضافة نوع الـ IP)
// ============================================================

@interface AtlantaReportViewController : UIViewController
@end

@implementation AtlantaReportViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    
    NSString *udidStr = fakeVendorID ? [fakeVendorID UUIDString] : [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *idfaStr = fakeAdvertisingID ? [fakeAdvertisingID UUIDString] : [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي:\n%@\n📌 نوع الـ IP: %@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", currentISPType, currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 تفاصيل الطلبات:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 160);
    [scrollView addSubview:label];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 30, 80, 35);
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}

- (void)dismissPopup {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ============================================================
// MARK: - النافذة العائمة والزر (بدون تأكيد)
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    if (btn && CGRectContainsPoint(btn.frame, point)) {
        return YES;
    }
    return NO;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *floatingBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation AtlantaInfoManager

+ (instancetype)sharedInstance {
    static AtlantaInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatingBtn.tag = 999888;
        self.floatingBtn.frame = CGRectMake(20, 120, 60, 60);
        self.floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.9];
        [self.floatingBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [self.floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
        self.floatingBtn.layer.cornerRadius = 30;
        self.floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.floatingBtn.layer.shadowOpacity = 0.5;
        self.floatingBtn.layer.shadowRadius = 5;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.floatingBtn addGestureRecognizer:pan];
        
        [self.floatingBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.floatingBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    CGFloat newX = btn.center.x + translation.x;
    CGFloat newY = btn.center.y + translation.y;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newX = MAX(30, MIN(screenSize.width - 30, newX));
    newY = MAX(40, MIN(screenSize.height - 40, newY));
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}

- (void)handleReset {
    performFullReset();
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    UIAlertController *done = [UIAlertController alertControllerWithTitle:@"تم"
                                                                  message:@"تمت إعادة الضبط بنجاح"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [done addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:done animated:YES completion:nil];
}

@end

// ============================================================
// MARK: - الـ Hooks باستخدام %hook
// ============================================================

%ctor {
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingButton];
    });
}

%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end

%hook NSURLConnection
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    %orig(mutableReq, queue, handler);
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (fakeVendorID) {
        return fakeVendorID;
    }
    return %orig;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (fakeAdvertisingID) {
        return fakeAdvertisingID;
    }
    return %orig;
}
%end
