//
//  TBTRootController.m
//  TabBar26Prefs
//

#import "TBTRootController.h"
#import "TBTPreferences.h"
#import "TBTScopeController.h"
#import "TBTAppsController.h"

typedef NS_ENUM(NSInteger, TBTRootSection) {
    TBTRootSectionHeader = 0,
    TBTRootSectionUsage,
    TBTRootSectionInteraction,
    TBTRootSectionAbout,
    TBTRootSectionCount
};

@implementation TBTRootController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TabBar26";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return TBTRootSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case TBTRootSectionHeader: return 1;
        case TBTRootSectionUsage: return 3;
        case TBTRootSectionInteraction: return 1;
        case TBTRootSectionAbout: return 3;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == TBTRootSectionUsage) return @"外观";
    if (section == TBTRootSectionInteraction) return @"交互";
    if (section == TBTRootSectionAbout) return @"关于";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == TBTRootSectionUsage) {
        return @"应用到全部 App，或只对勾选的 App 生效。修改后立即下发，无需注销设备。";
    }
    if (section == TBTRootSectionInteraction) {
        return @"在悬浮底栏上左右滑动可切换相邻页面；点按仍然交给系统 tab 按钮，不拦截触摸。";
    }
    if (section == TBTRootSectionAbout) {
        return @"只调整底栏外观，不改动 App 的布局、手势与交互逻辑；自绘底栏的 App 会自动跳过。";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == TBTRootSectionHeader) return 84.0;
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == TBTRootSectionHeader) {
        static NSString *identifier = @"TBTRootHeaderCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
            cell.detailTextLabel.numberOfLines = 2;
        }
        cell.textLabel.text = @"TabBar26";
        cell.detailTextLabel.text = @"iOS 26 悬浮玻璃底栏 · iOS 15–16 · arm64e";
        cell.imageView.image = TBTSymbolImage(@"capsule.fill", [UIColor systemTealColor]);
        return cell;
    }

    if (indexPath.section == TBTRootSectionUsage) {
        if (indexPath.row == 0) {
            static NSString *identifier = @"TBTRootSwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UISwitch *toggle = [[UISwitch alloc] init];
                [toggle addTarget:self action:@selector(enabledSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            }
            UISwitch *toggle = (UISwitch *)cell.accessoryView;
            toggle.on = TBTGetEnabled();
            cell.textLabel.text = @"启用";
            cell.imageView.image = TBTSymbolImage(@"power", [UIColor systemGreenColor]);
            return cell;
        }

        static NSString *identifier = @"TBTRootValueCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }

        if (indexPath.row == 1) {
            cell.textLabel.text = @"应用范围";
            cell.imageView.image = TBTSymbolImage(@"square.stack.3d.up.fill", [UIColor systemIndigoColor]);
            cell.detailTextLabel.text = (TBTGetScope() == 0) ? @"全部 App" : @"仅选中的 App";
        } else {
            NSUInteger count = TBTGetSelectedApps().count;
            cell.textLabel.text = @"选择 App";
            cell.imageView.image = TBTSymbolImage(@"apps.iphone", [UIColor systemBlueColor]);
            cell.detailTextLabel.text = count > 0 ? [NSString stringWithFormat:@"已选 %lu 个", (unsigned long)count] : @"未选择";
        }
        return cell;
    }

    if (indexPath.section == TBTRootSectionInteraction) {
        static NSString *identifier = @"TBTRootSwipeSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(swipeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.on = TBTGetSwipeEnabled();
        cell.textLabel.text = @"底栏滑动切页";
        cell.imageView.image = TBTSymbolImage(@"hand.draw.fill", [UIColor systemPinkColor]);
        return cell;
    }

    static NSString *identifier = @"TBTRootAboutCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"版本";
        cell.imageView.image = TBTSymbolImage(@"info.circle.fill", [UIColor systemGrayColor]);
        NSString *version = [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleShortVersionString"];
        cell.detailTextLabel.text = version ?: @"0.0.1";
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"构建方式";
        cell.imageView.image = TBTSymbolImage(@"hammer.fill", [UIColor systemOrangeColor]);
        cell.detailTextLabel.text = @"GitHub Actions";
    } else {
        cell.textLabel.text = @"最近生效";
        cell.imageView.image = TBTSymbolImage(@"waveform.path.ecg", [UIColor systemPurpleColor]);
        cell.detailTextLabel.text = TBTDiagnosticSummary();
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        cell.detailTextLabel.minimumScaleFactor = 0.7;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != TBTRootSectionUsage) return;

    if (indexPath.row == 1) {
        TBTScopeController *controller = [[TBTScopeController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
    } else if (indexPath.row == 2) {
        TBTAppsController *controller = [[TBTAppsController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

#pragma mark - Actions

- (void)enabledSwitchChanged:(UISwitch *)sender {
    TBTSetEnabled(sender.isOn);
}

- (void)swipeSwitchChanged:(UISwitch *)sender {
    TBTSetSwipeEnabled(sender.isOn);
}

@end
