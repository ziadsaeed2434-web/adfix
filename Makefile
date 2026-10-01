TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdPurgeTweak

# Include all necessary frameworks
AdPurgeTweak_FRAMEWORKS = Foundation UIKit Security AdSupport
AdPurgeTweak_PRIVATE_FRAMEWORKS = AppTrackingTransparency
AdPurgeTweak_LIBRARIES = substrate
AdPurgeTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# إضافة جميع ملفات FLEX الضرورية لتجنب أخطاء الـ Undefined symbols
AdPurgeTweak_FILES = FLEXNetworkObserver.m FLEXNetworkRecorder.m FLEXUtility.m

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 TargetAppName || true"
