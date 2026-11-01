//
//  TBTIconProvider.h
//  TabBar26Prefs
//

#import <UIKit/UIKit.h>
#import "TBTAppCatalog.h"

/// App 图标：优先系统图标服务，退回 App 包里的 png，拿不到返回 nil。
UIImage *TBTIconForApp(TBTAppInfo *app);

/// 图标是否是一张接近纯白的空图（系统内部 App 常见），用来在列表里过滤掉它们。
BOOL TBTIconIsBlank(UIImage *image);
