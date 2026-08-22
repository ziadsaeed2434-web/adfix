TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdFixerPro

AdFixerPro_FILES = Tweak.x
AdFixerPro_FRAMEWORKS = UIKit Foundation

ADDITIONAL_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-unguarded-availability-new
ADDITIONAL_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk
