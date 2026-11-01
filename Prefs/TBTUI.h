//
//  TBTUI.h
//  TabBar26Prefs
//

#import <UIKit/UIKit.h>

/// Preferences.framework 里的基类。这里只做声明，实际实现由 Preferences 进程在运行时提供，
/// 面板控制器必须继承它，否则 PSListController controllerForSpecifier: 会因为
/// initForContentSize: / setParentController: 等 selector 缺失而崩溃。
@interface PSViewController : UIViewController
@end

/// 统一的表格式面板基类：insetGrouped 表格 + 约束，风格与 AppPro 面板一致。
@interface TBTTableViewController : PSViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end

/// SF Symbols 取图并着色（AlwaysOriginal 保证颜色不被系统改成默认蓝）。
UIImage *TBTSymbolImage(NSString *name, UIColor *tint);
