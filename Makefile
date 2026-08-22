PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdFixerPro

AdFixerPro_FILES = Tweak.x
AdFixerPro_FRAMEWORKS = UIKit Foundation

# أجبِر المترجم على تجاهل هذه الأخطاء والتحذيرات لتنجح عملية البناء
ADDITIONAL_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-incompatible-pointer-types -Wno-unguarded-availability-new

include $(THEOS_MAKE_PATH)/tweak.mk
