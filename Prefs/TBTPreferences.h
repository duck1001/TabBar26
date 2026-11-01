//
//  TBTPreferences.h
//  TabBar26Prefs
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

@interface TBTAppInfo : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *name;
@end

/// 已安装 App 列表，按名称排序。LSApplicationWorkspace 不可用时回退扫描目录。
NSArray<TBTAppInfo *> *TBTInstalledApps(void);
