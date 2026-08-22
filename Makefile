PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdFixerPro

AdFixerPro_FILES = Tweak.x
AdFixerPro_FRAMEWORKS = UIKit Foundation

ADDITIONAL_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-unguarded-availability-new

include $(THEOS_MAKE_PATH)/tweak.mk
