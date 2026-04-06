TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Vantage

Vantage_FILES = Tweak.x
Vantage_FRAMEWORKS = UIKit ReplayKit AVFoundation Photos CoreMedia
Vantage_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
