//
//  TBTBarStyler.h
//  TabBar26
//

#import <UIKit/UIKit.h>

/// 应用 / 还原某个底栏（幂等，可在 layoutSubviews 里反复调用）。
void TBTStyleBar(UITabBar *bar);
void TBTRestoreBar(UITabBar *bar);

/// 设置变更后刷新当前进程所有底栏。
void TBTRefreshAllBars(void);

/// 选中项变化时让内部滑块动起来。
void TBTUpdatePillAnimated(UITabBar *bar);

/// 改造期间拦截 App 对 appearance 的覆盖（同时避免 setter 递归）。
BOOL TBTBlocksAppearanceChange(UITabBar *bar, UITabBarAppearance *appearance);
