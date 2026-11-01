//
//  TBTSwipe.h
//  TabBar26
//

#import <UIKit/UIKit.h>

/// 按当前开关挂载 / 移除底栏左右滑动切页手势（幂等）。
void TBTSyncGestures(UITabBar *bar);
void TBTRemoveGestures(UITabBar *bar);
