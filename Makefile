THEOS = /opt/theos
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ProAdManager
ProAdManager_FILES = Tweak.x
ProAdManager_FRAMEWORKS = UIKit Foundation SystemConfiguration AdSupport

include $(THEOS_MAKE_PATH)/tweak.mk
