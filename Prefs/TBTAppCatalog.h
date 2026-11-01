//
//  TBTAppCatalog.h
//  TabBar26Prefs
//
//  已安装应用清单：App Store / 巨魔 / 越狱商店 / 系统 App 合并去重。
//

#import <Foundation/Foundation.h>

@interface TBTAppInfo : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundlePath;
@end

NSArray<TBTAppInfo *> *TBTInstalledApps(void);
