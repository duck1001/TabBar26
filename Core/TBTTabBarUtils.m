//
//  TBTTabBarUtils.m
//  TabBar26
//
//  底栏宿主判定：优先 responder 链，找不到再看 delegate（兼容自定义容器）。
//

#import "TBTShared.h"

UITabBarController *TBTContainingTabBarController(UITabBar *bar) {
    UIResponder *responder = bar.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:[UITabBarController class]]) {
            return (UITabBarController *)responder;
        }
        if ([responder isKindOfClass:[UIWindow class]]) break;
        responder = responder.nextResponder;
    }
    id delegate = bar.delegate;
    if ([delegate isKindOfClass:[UITabBarController class]]) {
        return (UITabBarController *)delegate;
    }
    return nil;
}

BOOL TBTIsRealTabBar(UITabBar *bar) {
    if (TBTContainingTabBarController(bar)) return YES;

    // 兜底：没挂在 UITabBarController 上、但确实贴着窗口底部的原生 UITabBar
    // （部分 App 用自定义容器托管底栏）
    if (bar.window && bar.items.count >= 2) {
        CGRect frame = [bar convertRect:bar.bounds toView:bar.window];
        if (CGRectGetMaxY(frame) >= CGRectGetHeight(bar.window.bounds) - 2.0) return YES;
    }
    return NO;
}

BOOL TBTShouldStyle(UITabBar *bar) {
    if (!TBTProcessEligible()) return NO;
    if (!TBTEnabledForBundle([NSBundle mainBundle].bundleIdentifier)) return NO;
    if (!bar || bar.isHidden || bar.alpha < 0.01f) return NO;
    if (bar.items.count == 0) return NO;
    if (bar.bounds.size.width < 120.0 || bar.bounds.size.height < 20.0) return NO;
    if (!TBTIsRealTabBar(bar)) return NO;
    return YES;
}
