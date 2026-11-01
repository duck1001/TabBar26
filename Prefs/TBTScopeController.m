//
//  TBTScopeController.m
//  TabBar26Prefs
//

#import "TBTScopeController.h"
#import "TBTPreferences.h"

@implementation TBTScopeController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"应用范围";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"「全部 App」对每个 App 的原生底栏生效；「仅选中的 App」只对「选择 App」里勾选的应用生效。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"TBTScopeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }

    NSInteger scope = TBTGetScope();
    cell.tag = indexPath.row;
    if (indexPath.row == 0) {
        cell.textLabel.text = @"全部 App";
        cell.detailTextLabel.text = @"所有应用的原生底栏";
        cell.imageView.image = TBTSymbolImage(@"square.grid.2x2.fill", [UIColor systemIndigoColor]);
    } else {
        cell.textLabel.text = @"仅选中的 App";
        cell.detailTextLabel.text = @"只处理「选择 App」里勾选的应用";
        cell.imageView.image = TBTSymbolImage(@"checklist", [UIColor systemTealColor]);
    }
    cell.accessoryType = (indexPath.row == scope) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TBTSetScope(indexPath.row);
    [self.tableView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

@end
