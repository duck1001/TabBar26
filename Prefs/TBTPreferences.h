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
