//
//  TBTShared.h
//  TabBar26
//
//  注入端公用声明：偏好读取、进程判定、底栏宿主判定。
//

#import <UIKit/UIKit.h>

extern NSString *const TBTDomain;
extern NSString *const TBTPrefsChangedNotification;

/// 只允许 App 容器内的进程参与（SpringBoard / 设置 / 扩展 / 守护进程返回 NO）。
BOOL TBTProcessEligible(void);

/// 当前 App 是否在当前生效范围内（全部 App 或勾选列表）。
BOOL TBTEnabledForBundle(NSString *bundleID);

/// 底栏滑动切页开关，默认开。
BOOL TBTSwipeEnabled(void);

/// 最近的一个 UITabBarController（responder 链优先，其次 delegate）。
UITabBarController *TBTContainingTabBarController(UITabBar *bar);

/// 是否是真正的底栏（有 UITabBarController 宿主）。
BOOL TBTIsRealTabBar(UITabBar *bar);

/// 是否应该改造这个底栏（进程 / 范围 / 可见性 / 尺寸 / 宿主）。
BOOL TBTShouldStyle(UITabBar *bar);
