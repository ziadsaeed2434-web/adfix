include $(THEOS)/makefiles/common.mk

TARGET = iphone:clang:latest:14.0
ARCHS = arm64

TWEAK_NAME = ProAdManager
ProAdManager_FILES = Tweak.x
ProAdManager_FRAMEWORKS = UIKit CoreLocation WebKit Foundation SystemConfiguration AdSupport

# هذا السطر هو السر لإلغاء الارتباط بـ Cydia Substrate نهائياً
ProAdManager_LDFLAGS = -Wl,-flat_namespace,-undefined,suppress

include $(THEOS_MAKE_PATH)/tweak.mk
