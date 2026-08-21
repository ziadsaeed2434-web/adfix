TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdFixerPro

AdFixerPro_FILES = Tweak.x
AdFixerPro_FRAMEWORKS = UIKit Foundation AdSupport SystemConfiguration

include $(THEOS_MAKE_PATH)/tweak.mk
