TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdPurgeTweak

AdPurgeTweak_FILES = Tweak.x FLEXNetworkObserver.m FLEXNetworkRecorder.m FLEXNetworkTransaction.m FLEXResources.m FLEXUtility.m
AdPurgeTweak_FRAMEWORKS = Foundation UIKit Security AdSupport
AdPurgeTweak_PRIVATE_FRAMEWORKS = AppTrackingTransparency
AdPurgeTweak_EXTRA_FRAMEWORKS = GoogleMobileAds
AdPurgeTweak_LIBRARIES = substrate
AdPurgeTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-gnu-folding-constant

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Activator || true"
