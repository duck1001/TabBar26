//
//  Tweak.xm
//  TabBar26
//
//  只放 hook 入口，实际逻辑在 Core/ 下按功能拆分：
//    TBTPrefs.m          偏好读取
//    TBTProcessGuard.m   进程收口
//    TBTTabBarUtils.m    底栏宿主判定
//    TBTBarStyler.m      玻璃外观 + 内部滑块
//    TBTSwipe.m          左右滑动切页
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

#import "TBTShared.h"
#import "TBTBarStyler.h"

static void TBTOnPrefsChanged(CFNotificationCenterRef center,
                              void *observer,
                              CFStringRef name,
                              const void *object,
                              CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TBTRefreshAllBars();
    });
}

%hook UITabBar

- (void)layoutSubviews {
    %orig;
    TBTStyleBar(self);
}

- (void)didMoveToWindow {
    %orig;
    TBTStyleBar(self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    TBTStyleBar(self);
}

- (void)setItems:(NSArray<UITabBarItem *> *)items animated:(BOOL)animated {
    %orig;
    TBTStyleBar(self);
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    if (!hidden) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TBTStyleBar(self);
        });
    }
}

- (void)setSelectedItem:(UITabBarItem *)selectedItem {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        TBTUpdatePillAnimated(self);
    });
}

// App 在生命周期里反复改 appearance 时，保持我们的透明配置不被覆盖，
// 同时避免「App 设 → 我们改 → 触发布局 → App 再设」的死循环。
- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance {
    if (TBTBlocksAppearanceChange(self, standardAppearance)) return;
    %orig;
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance {
    if (TBTBlocksAppearanceChange(self, scrollEdgeAppearance)) return;
    %orig;
}

%end

%hook UITabBarController

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    UITabBar *bar = self.tabBar;
    dispatch_async(dispatch_get_main_queue(), ^{
        TBTUpdatePillAnimated(bar);
    });
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig;
    UITabBar *bar = self.tabBar;
    dispatch_async(dispatch_get_main_queue(), ^{
        TBTUpdatePillAnimated(bar);
    });
}

%end

%ctor {
    if (!TBTProcessEligible()) return;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    TBTOnPrefsChanged,
                                    (__bridge CFStringRef)TBTPrefsChangedNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
