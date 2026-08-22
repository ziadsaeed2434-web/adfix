include $(THEOS)/makefiles/common.mk

TARGET = iphone:clang:latest:14.0
ARCHS = arm64

TWEAK_NAME = ProAdManager
ProAdManager_FILES = Tweak.x
ProAdManager_FRAMEWORKS = UIKit Foundation SystemConfiguration AdSupport

include $(THEOS_MAKE_PATH)/tweak.mk
