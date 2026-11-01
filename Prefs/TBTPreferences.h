//
//  TBTPreferences.h
//  TabBar26Prefs
//
//  偏好项读写。应用清单在 TBTAppCatalog，图标在 TBTIconProvider。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const TBTPreferencesDomain;
extern NSString *const TBTPreferencesChangedNotification;

BOOL TBTGetEnabled(void);
void TBTSetEnabled(BOOL enabled);

NSInteger TBTGetScope(void);              // 0 = 全部 App, 1 = 仅选中的 App
void TBTSetScope(NSInteger scope);

NSArray<NSString *> *TBTGetSelectedApps(void);
void TBTSetSelectedApps(NSArray<NSString *> *bundleIDs);

BOOL TBTGetSwipeEnabled(void);
void TBTSetSwipeEnabled(BOOL enabled);

/// 诊断：读取某个事件（lastInjected / lastStyled）最近一次写入的 App 与时间。
NSString *TBTDiagnosticSummary(NSString *prefix);
