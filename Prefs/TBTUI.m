//
//  TBTUI.m
//  TabBar26Prefs
//

#import "TBTUI.h"

UIImage *TBTSymbolImage(NSString *name, UIColor *tint) {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:19
                                                                                              weight:UIImageSymbolWeightMedium];
        UIImage *image = [UIImage systemImageNamed:name withConfiguration:config];
        if (!image) return nil;
        return [image imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return nil;
}

@implementation TBTTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    // 固定用 insetGrouped：面板可能由 PreferenceLoader 通过 initForContentSize: 创建，
    // 不能依赖自定义 init 传样式。
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 44.0;
    [self.view addSubview:tableView];
    self.tableView = tableView;

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

@end
