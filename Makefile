TARGET := iphone:clang:latest:15.0
ARCHS = arm64e

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TabBar26
TabBar26_FILES = Tweak.xm Core/TBTPrefs.m Core/TBTProcessGuard.m Core/TBTTabBarUtils.m Core/TBTBarStyler.m Core/TBTSwipe.m Shared/TBTNotify.m
TabBar26_FRAMEWORKS = UIKit Foundation QuartzCore
TabBar26_CFLAGS = -fobjc-arc -Os -Wno-deprecated-declarations -ICore -IShared
TabBar26_LDFLAGS = -undefined dynamic_lookup -Wl,-dead_strip

BUNDLE_NAME = TabBar26Prefs
TabBar26Prefs_FILES = Prefs/TBTPreferences.m Prefs/TBTAppCatalog.m Prefs/TBTIconProvider.m Prefs/TBTUI.m Prefs/TBTRootController.m Prefs/TBTScopeController.m Prefs/TBTAppsController.m Shared/TBTNotify.m
TabBar26Prefs_FRAMEWORKS = UIKit Foundation
TabBar26Prefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -IPrefs -IShared
TabBar26Prefs_INSTALL_PATH = /Library/PreferenceBundles
TabBar26Prefs_RESOURCE_FILES = Prefs/Info.plist Prefs/icon.png Prefs/icon@2x.png Prefs/icon@3x.png
TabBar26Prefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard Preferences"
