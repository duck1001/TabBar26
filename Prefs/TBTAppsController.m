//
//  TBTAppsController.m
//  TabBar26Prefs
//

#import "TBTAppsController.h"
#import "TBTPreferences.h"

@interface TBTAppSwitch : UISwitch
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@implementation TBTAppSwitch
@end

@interface TBTAppsController () <UISearchResultsUpdating>
@end

@implementation TBTAppsController {
    NSArray<TBTAppInfo *> *_apps;
    NSArray<TBTAppInfo *> *_filtered;
    NSMutableSet<NSString *> *_selected;
    UISearchController *_searchController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择 App";

    _apps = TBTInstalledApps();
    _filtered = _apps;
    _selected = [NSMutableSet setWithArray:TBTGetSelectedApps()];

    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;
    _searchController.searchBar.placeholder = @"搜索 App";
    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Data

static UIColor *TBTColorForIdentifier(NSString *bundleIdentifier) {
    NSUInteger hash = bundleIdentifier.hash;
    CGFloat hue = (CGFloat)(hash % 360) / 360.0;
    return [UIColor colorWithHue:hue saturation:0.52 brightness:0.88 alpha:1.0];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *keyword = searchController.searchBar.text.lowercaseString;
    if (keyword.length == 0) {
        _filtered = _apps;
    } else {
        NSMutableArray<TBTAppInfo *> *result = [NSMutableArray array];
        for (TBTAppInfo *app in _apps) {
            if ([app.name.lowercaseString containsString:keyword] ||
                [app.bundleIdentifier.lowercaseString containsString:keyword]) {
                [result addObject:app];
            }
        }
        _filtered = result;
    }
    [self.tableView reloadData];
}

- (void)persistSelection {
    NSArray *sorted = [[_selected allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    TBTSetSelectedApps(sorted);
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filtered.count > 0 ? _filtered.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _filtered.count > 0 ? [NSString stringWithFormat:@"已安装应用 · 已选 %lu 个", (unsigned long)_selected.count] : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"只有「应用范围」选择「仅选中的 App」时，这里的勾选才会生效。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_filtered.count == 0) {
        static NSString *identifier = @"TBTAppsEmptyCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
            cell.imageView.image = TBTSymbolImage(@"exclamationmark.triangle.fill", [UIColor systemOrangeColor]);
        }
        cell.textLabel.text = (_apps.count == 0) ? @"未能读取应用列表" : @"没有匹配的 App";
        return cell;
    }

    static NSString *identifier = @"TBTAppsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = [UIColor tertiaryLabelColor];
    }

    TBTAppInfo *app = _filtered[indexPath.row];
    cell.textLabel.text = app.name;
    cell.detailTextLabel.text = app.bundleIdentifier;
    UIImage *icon = TBTIconForApp(app);
    if (!icon) icon = TBTSymbolImage(@"app.fill", TBTColorForIdentifier(app.bundleIdentifier));
    cell.imageView.image = icon;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;

    TBTAppSwitch *toggle = (TBTAppSwitch *)cell.accessoryView;
    if (![toggle isKindOfClass:[TBTAppSwitch class]]) {
        toggle = [[TBTAppSwitch alloc] init];
        [toggle addTarget:self action:@selector(appSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    }
    toggle.bundleIdentifier = app.bundleIdentifier;
    toggle.on = [_selected containsObject:app.bundleIdentifier];
    return cell;
}

#pragma mark - Actions

- (void)appSwitchChanged:(TBTAppSwitch *)sender {
    NSString *bundleIdentifier = sender.bundleIdentifier;
    if (bundleIdentifier.length == 0) return;

    BOOL on = sender.isOn;
    if (on) [_selected addObject:bundleIdentifier];
    else [_selected removeObject:bundleIdentifier];

    [self persistSelection];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationNone];
}

@end
