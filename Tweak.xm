//
//  Tweak.xm
//  TabBar26 — iOS 26 style floating glass tab bar for iOS 15–16
//
//  Design notes (why it is built this way):
//   • 只改外观，不动 frame / 不接管手势 / 不拦截触摸。底栏的布局、safe area、
//     hidesBottomBarWhenPushed 动画、键盘避让全部保持系统逻辑，避免破坏 App 内部行为。
//   • 只处理真正属于 UITabBarController 的 UITabBar；自绘底栏、被 App 自己容器
//     托管的 bar 一律跳过（避让 App 内部实现）。
//   • 玻璃容器 userInteractionEnabled = NO，命中测试完全落到系统控件上。
//   • 应用层级：插入到 _UIBarBackground 之上、tab 按钮之下，不覆盖图标。
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString *const TBTDomain = @"com.milkway.tabbar26";
static NSString *const TBTPrefsChanged = @"com.milkway.tabbar26/prefsChanged";

static char kTBTContainerKey;
static char kTBTEffectKey;
static char kTBTAppearanceKey;
static char kTBTSavedStandardKey;
static char kTBTSavedScrollKey;
static char kTBTSavedImageKey;
static char kTBTSavedShadowKey;
static char kTBTGesturesKey;

#pragma mark - Preferences (read side)

static char *TBTJBPath(const char *path) {
    static char *(*jbrootFn)(const char *) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jbrootFn = (char *(*)(const char *))dlsym(RTLD_DEFAULT, "jbroot");
    });
    return jbrootFn ? jbrootFn(path) : NULL;
}

static NSDictionary *TBTReadPrefsFromFile(void) {
    NSArray<NSString *> *candidates = @[
        @"/var/mobile/Library/Preferences/com.milkway.tabbar26.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.milkway.tabbar26.plist",
    ];
    for (NSString *path in candidates) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict) return dict;
        char *jb = TBTJBPath(path.fileSystemRepresentation);
        if (jb) {
            dict = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithUTF8String:jb]];
            if (dict) return dict;
        }
    }
    return nil;
}

static NSDictionary *TBTLoadPrefs(void) {
    static NSLock *lock = nil;
    static NSDictionary *cache = nil;
    static CFAbsoluteTime stamp = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lock = [NSLock new]; });

    [lock lock];
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (cache && (now - stamp) < 0.4) {
        NSDictionary *snapshot = cache;
        [lock unlock];
        return snapshot;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    CFStringRef domain = (__bridge CFStringRef)TBTDomain;
    CFArrayRef keys = (__bridge CFArrayRef)@[ @"enabled", @"scope", @"selectedApps", @"swipeEnabled" ];
    CFDictionaryRef values = CFPreferencesCopyMultiple(keys, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (values) {
        [(__bridge NSDictionary *)values enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if (key) result[key] = value;
        }];
        CFRelease(values);
    }
    if (result.count == 0) {
        NSDictionary *file = TBTReadPrefsFromFile();
        if (file) [result addEntriesFromDictionary:file];
    }

    cache = [result copy];
    stamp = now;
    NSDictionary *snapshot = cache;
    [lock unlock];
    return snapshot;
}

static BOOL TBTEnabledForBundle(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    NSDictionary *prefs = TBTLoadPrefs();

    NSNumber *enabled = prefs[@"enabled"];
    if ([enabled isKindOfClass:[NSNumber class]] && ![enabled boolValue]) return NO;

    id scopeValue = prefs[@"scope"];
    NSInteger scope = [scopeValue respondsToSelector:@selector(integerValue)] ? [scopeValue integerValue] : 0;
    if (scope == 0) return YES;

    id list = prefs[@"selectedApps"];
    if (![list isKindOfClass:[NSArray class]]) return NO;
    for (id item in (NSArray *)list) {
        if ([item isKindOfClass:[NSString class]] && [item isEqualToString:bundleID]) return YES;
    }
    return NO;
}

#pragma mark - Process guard

static BOOL TBTProcessEligible(void) {
    static BOOL eligible = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *main = [NSBundle mainBundle];
        NSString *bundleID = main.bundleIdentifier;
        NSString *path = main.bundlePath ?: @"";
        if (bundleID.length == 0) return;

        BOOL insideAppContainer =
            [path containsString:@"/Bundle/Application/"] ||
            [path containsString:@"/Applications/"] ||
            [path containsString:@"/var/jb/Applications/"];
        if (!insideAppContainer) return;

        // 设置 / SpringBoard 等系统宿主不处理
        if ([bundleID isEqualToString:@"com.apple.Preferences"] ||
            [bundleID isEqualToString:@"com.apple.springboard"] ||
            [bundleID hasPrefix:@"com.apple.Preferences."]) return;

        eligible = YES;
    });
    return eligible;
}

#pragma mark - Helpers

static UITabBarController *TBTContainingTabBarController(UITabBar *bar) {
    UIResponder *responder = bar.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:[UITabBarController class]]) {
            UITabBarController *controller = (UITabBarController *)responder;
            return (controller.tabBar == bar) ? controller : nil;
        }
        if ([responder isKindOfClass:[UIWindow class]]) break;
        responder = responder.nextResponder;
    }
    return nil;
}

static BOOL TBTIsRealTabBar(UITabBar *bar) {
    return TBTContainingTabBarController(bar) != nil;
}

static BOOL TBTShouldStyle(UITabBar *bar) {
    if (!TBTProcessEligible()) return NO;
    if (!TBTEnabledForBundle([NSBundle mainBundle].bundleIdentifier)) return NO;
    if (!bar || bar.isHidden || bar.alpha < 0.01f) return NO;
    if (bar.items.count == 0) return NO;
    if (bar.bounds.size.width < 120.0 || bar.bounds.size.height < 20.0) return NO;
    if (!TBTIsRealTabBar(bar)) return NO;
    return YES;
}

#pragma mark - Swipe to switch tab

static BOOL TBTSwipeEnabled(void) {
    NSDictionary *prefs = TBTLoadPrefs();
    NSNumber *value = prefs[@"swipeEnabled"];
    return value ? [value boolValue] : YES;
}

/// 只在底栏范围内识别左右滑动；cancelsTouchesInView = NO，点按照旧走系统 tab 按钮。
@interface TBTGestureProxy : NSObject
+ (instancetype)sharedProxy;
- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer;
@end

@implementation TBTGestureProxy

+ (instancetype)sharedProxy {
    static TBTGestureProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [TBTGestureProxy new];
    });
    return proxy;
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    UITabBar *bar = (UITabBar *)recognizer.view;
    if (![bar isKindOfClass:[UITabBar class]]) return;
    if (!TBTShouldStyle(bar)) return;
    if (!TBTSwipeEnabled()) return;

    UITabBarController *controller = TBTContainingTabBarController(bar);
    if (!controller) return;

    NSArray<UIViewController *> *controllers = controller.viewControllers;
    NSInteger count = (NSInteger)controllers.count;
    if (count < 2) return;

    NSInteger index = controller.selectedIndex;
    NSInteger target = (recognizer.direction == UISwipeGestureRecognizerDirectionLeft) ? index + 1 : index - 1;
    if (target < 0 || target >= count) return;

    UIViewController *destination = controllers[(NSUInteger)target];
    id<UITabBarControllerDelegate> delegate = controller.delegate;
    // 尊重 App 自己的 shouldSelect 逻辑（例如未登录拦截），不硬切
    if ([delegate respondsToSelector:@selector(tabBarController:shouldSelectViewController:)]) {
        if (![delegate tabBarController:controller shouldSelectViewController:destination]) return;
    }
    controller.selectedViewController = destination;
    if ([delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) {
        [delegate tabBarController:controller didSelectViewController:destination];
    }
}

@end

static void TBTInstallGestures(UITabBar *bar) {
    if (objc_getAssociatedObject(bar, &kTBTGesturesKey)) return;

    NSMutableArray<UISwipeGestureRecognizer *> *recognizers = [NSMutableArray array];
    NSArray<NSNumber *> *directions = @[
        @(UISwipeGestureRecognizerDirectionLeft),
        @(UISwipeGestureRecognizerDirectionRight),
    ];
    for (NSNumber *direction in directions) {
        UISwipeGestureRecognizer *swipe =
            [[UISwipeGestureRecognizer alloc] initWithTarget:[TBTGestureProxy sharedProxy]
                                                      action:@selector(handleSwipe:)];
        swipe.direction = (UISwipeGestureRecognizerDirection)direction.integerValue;
        swipe.cancelsTouchesInView = NO;
        swipe.delaysTouchesBegan = NO;
        swipe.delaysTouchesEnded = NO;
        [bar addGestureRecognizer:swipe];
        [recognizers addObject:swipe];
    }
    objc_setAssociatedObject(bar, &kTBTGesturesKey, recognizers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TBTRemoveGestures(UITabBar *bar) {
    NSArray<UISwipeGestureRecognizer *> *recognizers = objc_getAssociatedObject(bar, &kTBTGesturesKey);
    if (!recognizers) return;
    for (UISwipeGestureRecognizer *swipe in recognizers) {
        [bar removeGestureRecognizer:swipe];
    }
    objc_setAssociatedObject(bar, &kTBTGesturesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Appearance

static void TBTRestoreBar(UITabBar *bar);

static void TBTInstallGlass(UITabBar *bar) {
    if (objc_getAssociatedObject(bar, &kTBTContainerKey)) return;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.backgroundColor = [UIColor clearColor];
    container.userInteractionEnabled = NO;
    container.accessibilityElementsHidden = YES;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.16f;
    container.layer.shadowRadius = 18.0f;
    container.layer.shadowOffset = CGSizeMake(0, 8.0f);

    UIVisualEffectView *effect = nil;
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        effect = [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
        effect.contentView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        effect = [[UIVisualEffectView alloc] initWithEffect:blur];
    }
    effect.userInteractionEnabled = NO;
    effect.clipsToBounds = YES;
    effect.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:effect];

    UIView *sheen = [[UIView alloc] initWithFrame:CGRectZero];
    sheen.userInteractionEnabled = NO;
    sheen.tag = 0x7B27;
    sheen.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.06];
        return [UIColor colorWithWhite:1.0 alpha:0.28];
    }];
    [effect.contentView addSubview:sheen];

    objc_setAssociatedObject(bar, &kTBTContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(bar, &kTBTEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 插到系统背景之上、tab 按钮之下
    NSUInteger index = 0;
    for (NSUInteger i = 0; i < bar.subviews.count; i++) {
        UIView *sub = bar.subviews[i];
        if ([NSStringFromClass(sub.class) containsString:@"BarBackground"]) {
            index = i + 1;
            break;
        }
    }
    if (index > bar.subviews.count) index = bar.subviews.count;
    [bar insertSubview:container atIndex:index];
}

static void TBTUpdateGlass(UITabBar *bar) {
    UIView *container = objc_getAssociatedObject(bar, &kTBTContainerKey);
    UIVisualEffectView *effect = objc_getAssociatedObject(bar, &kTBTEffectKey);
    if (!container || !effect) return;

    CGRect bounds = bar.bounds;
    if (bounds.size.width < 1.0 || bounds.size.height < 1.0) return;

    CGFloat safeBottom = MAX(bar.safeAreaInsets.bottom, 0.0);
    CGFloat zone = MAX(bounds.size.height - safeBottom, 34.0);
    CGFloat height = zone - 6.0;
    if (height < 38.0) height = zone;
    height = MIN(height, bounds.size.height - 4.0);
    if (height < 30.0) height = bounds.size.height;

    CGFloat side = bounds.size.width < 340.0 ? 8.0 : 10.0;
    CGRect frame = CGRectMake(side, 2.0, bounds.size.width - side * 2.0, height);
    container.frame = frame;
    effect.frame = container.bounds;

    UIView *sheen = [effect.contentView viewWithTag:0x7B27];
    sheen.frame = effect.bounds;

    CGFloat radius = height / 2.0;
    effect.layer.cornerRadius = radius;
    container.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:container.bounds cornerRadius:radius].CGPath;

    CGFloat scale = bar.window.screen.scale;
    if (scale <= 0) scale = [UIScreen mainScreen].scale;
    if (scale <= 0) scale = 3.0;

    UITraitCollection *traits = bar.traitCollection;
    UIColor *border = [[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.16];
        return [UIColor colorWithWhite:1.0 alpha:0.55];
    }] resolvedColorWithTraitCollection:traits];

    effect.layer.borderWidth = 0.5 / scale;
    effect.layer.borderColor = border.CGColor;
}

static void TBTStyleBar(UITabBar *bar) {
    if (!TBTShouldStyle(bar)) {
        TBTRestoreBar(bar);
        return;
    }

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *current = bar.standardAppearance;
        UITabBarAppearance *applied = objc_getAssociatedObject(bar, &kTBTAppearanceKey);
        if (!applied || current != applied) {
            if (!applied) {
                if (current) objc_setAssociatedObject(bar, &kTBTSavedStandardKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (@available(iOS 15.0, *)) {
                    UITabBarAppearance *scroll = bar.scrollEdgeAppearance;
                    if (scroll) objc_setAssociatedObject(bar, &kTBTSavedScrollKey, scroll, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }

            UITabBarAppearance *appearance = current ? [current copy] : [[UITabBarAppearance alloc] init];
            // configureWithTransparentBackground 会重置部分 item 样式，先备份再还原，
            // 保证 App 自己定义的图标 / 文字颜色不被吃掉。
            UITabBarItemAppearance *stacked = [appearance.stackedLayoutAppearance copy];
            UITabBarItemAppearance *inlineLayout = [appearance.inlineLayoutAppearance copy];
            UITabBarItemAppearance *compactInline = [appearance.compactInlineLayoutAppearance copy];
            [appearance configureWithTransparentBackground];
            appearance.stackedLayoutAppearance = stacked;
            appearance.inlineLayoutAppearance = inlineLayout;
            appearance.compactInlineLayoutAppearance = compactInline;
            appearance.backgroundEffect = nil;
            appearance.backgroundColor = [UIColor clearColor];
            appearance.shadowColor = [UIColor clearColor];

            objc_setAssociatedObject(bar, &kTBTAppearanceKey, appearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            bar.standardAppearance = appearance;
            if (@available(iOS 15.0, *)) bar.scrollEdgeAppearance = appearance;
        }
    } else {
        if (!objc_getAssociatedObject(bar, &kTBTSavedImageKey)) {
            objc_setAssociatedObject(bar, &kTBTSavedImageKey, bar.backgroundImage ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(bar, &kTBTSavedShadowKey, bar.shadowImage ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        bar.backgroundImage = [UIImage new];
        bar.shadowImage = [UIImage new];
    }

    TBTInstallGlass(bar);
    TBTUpdateGlass(bar);

    if (TBTSwipeEnabled()) {
        TBTInstallGestures(bar);
    } else {
        TBTRemoveGestures(bar);
    }
}

static void TBTRestoreBar(UITabBar *bar) {
    UIView *container = objc_getAssociatedObject(bar, &kTBTContainerKey);
    UITabBarAppearance *applied = objc_getAssociatedObject(bar, &kTBTAppearanceKey);
    if (!container && !applied) return;

    if (container) [container removeFromSuperview];
    TBTRemoveGestures(bar);
    objc_setAssociatedObject(bar, &kTBTContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(bar, &kTBTEffectKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 先清标记再还原，避免 setter hook 把还原动作也挡掉
    objc_setAssociatedObject(bar, &kTBTAppearanceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id savedStandard = objc_getAssociatedObject(bar, &kTBTSavedStandardKey);
    if ([savedStandard isKindOfClass:[UITabBarAppearance class]]) bar.standardAppearance = savedStandard;
    objc_setAssociatedObject(bar, &kTBTSavedStandardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (@available(iOS 15.0, *)) {
        id savedScroll = objc_getAssociatedObject(bar, &kTBTSavedScrollKey);
        if ([savedScroll isKindOfClass:[UITabBarAppearance class]]) bar.scrollEdgeAppearance = savedScroll;
        objc_setAssociatedObject(bar, &kTBTSavedScrollKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    id savedImage = objc_getAssociatedObject(bar, &kTBTSavedImageKey);
    if (savedImage) bar.backgroundImage = (savedImage == [NSNull null]) ? nil : savedImage;
    objc_setAssociatedObject(bar, &kTBTSavedImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id savedShadow = objc_getAssociatedObject(bar, &kTBTSavedShadowKey);
    if (savedShadow) bar.shadowImage = (savedShadow == [NSNull null]) ? nil : savedShadow;
    objc_setAssociatedObject(bar, &kTBTSavedShadowKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Runtime refresh

static void TBTWalkViews(UIView *view, void (^block)(UIView *)) {
    block(view);
    NSArray<UIView *> *subviews = view.subviews;
    for (UIView *sub in subviews) {
        TBTWalkViews(sub, block);
    }
}

static void TBTRefreshAllBars(void) {
    if (!TBTProcessEligible()) return;
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return;
    for (UIWindow *window in app.windows) {
        TBTWalkViews(window, ^(UIView *view) {
            if ([view isKindOfClass:[UITabBar class]]) {
                TBTStyleBar((UITabBar *)view);
            }
        });
    }
}

static void TBTOnPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TBTRefreshAllBars();
    });
}

#pragma mark - Hooks

%hook UITabBar

- (void)layoutSubviews {
    %orig;
    TBTStyleBar(self);
}

- (void)didMoveToWindow {
    %orig;
    TBTStyleBar(self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    TBTUpdateGlass(self);
}

- (void)setItems:(NSArray<UITabBarItem *> *)items animated:(BOOL)animated {
    %orig;
    TBTStyleBar(self);
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    if (!hidden) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TBTStyleBar(self);
        });
    }
}

// App 在生命周期里反复改 appearance 时，保持我们的透明配置不被覆盖，
// 同时避免「App 设 → 我们改 → 触发布局 → App 再设」的死循环。
- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance {
    UITabBarAppearance *applied = objc_getAssociatedObject(self, &kTBTAppearanceKey);
    if (applied && standardAppearance != applied) return;
    %orig;
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance {
    UITabBarAppearance *applied = objc_getAssociatedObject(self, &kTBTAppearanceKey);
    if (applied && scrollEdgeAppearance != applied) return;
    %orig;
}

%end

%ctor {
    if (!TBTProcessEligible()) return;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    TBTOnPrefsChanged,
                                    (__bridge CFStringRef)TBTPrefsChanged,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
