PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdFixerPro

AdFixerPro_FILES = Tweak.x
AdFixerPro_FRAMEWORKS = UIKit Foundation

# إضافة راية لتجاهل خطأ تحويل مؤشرات الألوان والأنواع تحت نظام ARC
ADDITIONAL_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-incompatible-pointer-types -Wno-unguarded-availability-new -Wno-error=objc-pointer-conversion

include $(THEOS_MAKE_PATH)/tweak.mk
