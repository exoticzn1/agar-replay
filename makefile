TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Vantage

Vantage_FILES = Tweak.x
Vantage_FRAMEWORKS = UIKit ReplayKit AVFoundation Photos CoreMedia
# This line below prevents warnings from being treated as errors
Vantage_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
