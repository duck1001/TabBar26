//
//  TBTUI.h
//  TabBar26Prefs
//

#import <UIKit/UIKit.h>

/// 统一的表格式面板基类：insetGrouped 表格 + 约束，风格与 AppPro 面板一致。
@interface TBTTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

- (instancetype)initWithTableStyle:(UITableViewStyle)style;

@end

/// SF Symbols 取图并着色（AlwaysOriginal 保证颜色不被系统改成默认蓝）。
UIImage *TBTSymbolImage(NSString *name, UIColor *tint);
