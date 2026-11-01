//
//  TBTBarStyler.m
//  TabBar26
//
//  外观层：把原生 UITabBar 改成 iOS 26 的悬浮胶囊玻璃，并在内部加一个会滑动的选中滑块。
//  只改视觉，不动 frame / safe area / 手势。
//

#import "TBTBarStyler.h"
#import "TBTShared.h"
#import "TBTSwipe.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

static char kTBTContainerKey;
static char kTBTEffectKey;
static char kTBTAppearanceKey;
static char kTBTSavedStandardKey;
static char kTBTSavedScrollKey;
static char kTBTSavedImageKey;
static char kTBTSavedShadowKey;
static char kTBTSavedIndicatorKey;
static char kTBTPillKey;
static char kTBTCapsuleFrameKey;

#pragma mark - Geometry

static CGFloat TBTBarScale(UITabBar *bar) {
    CGFloat scale = bar.window.screen.scale;
    if (scale <= 0) scale = [UIScreen mainScreen].scale;
    if (scale <= 0) scale = 3.0;
    return scale;
}

/// 胶囊在底栏里的目标位置：横向留 10pt，纵向占安全区以上的内容带。
static CGRect TBTCapsuleFrame(UITabBar *bar) {
    CGRect bounds = bar.bounds;
    CGFloat safeBottom = MAX(bar.safeAreaInsets.bottom, 0.0);
    CGFloat zone = MAX(bounds.size.height - safeBottom, 34.0);
    CGFloat height = zone - 6.0;
    if (height < 38.0) height = zone;
    height = MIN(height, bounds.size.height - 4.0);
    if (height < 30.0) height = bounds.size.height;
    CGFloat side = bounds.size.width < 340.0 ? 8.0 : 10.0;
    return CGRectMake(side, 2.0, bounds.size.width - side * 2.0, height);
}

#pragma mark - Selection pill

static UIImage *TBTClearImage(void) {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.opaque = NO;
        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1) format:format];
        image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {}];
    });
    return image;
}

static UIView *TBTFindSelectedButton(UIView *view, NSInteger depth) {
    if (depth < 0) return nil;
    for (UIView *sub in view.subviews) {
        NSString *name = NSStringFromClass(sub.class);
        if (([name containsString:@"TabBarButton"] || [name containsString:@"TabBarItem"]) &&
            [sub respondsToSelector:@selector(isSelected)] && [(id)sub isSelected]) {
            return sub;
        }
        UIView *found = TBTFindSelectedButton(sub, depth - 1);
        if (found) return found;
    }
    return nil;
}

static UIView *TBTEnsurePill(UITabBar *bar) {
    UIView *pill = objc_getAssociatedObject(bar, &kTBTPillKey);
    if (pill) return pill;

    pill = [[UIView alloc] initWithFrame:CGRectZero];
    pill.userInteractionEnabled = NO;
    pill.accessibilityElementsHidden = YES;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.13];
        return [UIColor colorWithWhite:1.0 alpha:0.62];
    }];

    objc_setAssociatedObject(bar, &kTBTPillKey, pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *glass = objc_getAssociatedObject(bar, &kTBTContainerKey);
    if (glass) {
        [bar insertSubview:pill aboveSubview:glass];
    } else {
        [bar insertSubview:pill atIndex:0];
    }
    return pill;
}

/// 内部滑块：包住当前选中项（图标 + 文字）的一枚圆角胶囊。
/// 优先用真实按钮的 frame，找不到就按 item 序号和宽度均分兜底（5 个以上按 4+更多处理）。
static CGRect TBTPillFrame(UITabBar *bar) {
    CGRect capsule = TBTCapsuleFrame(bar);
    CGRect slot = CGRectZero;

    UIView *button = TBTFindSelectedButton(bar, 3);
    if (button) {
        slot = button.frame;
    } else {
        NSUInteger count = bar.items.count;
        if (count == 0) return CGRectNull;
        NSInteger selected = 0;
        UITabBarItem *selectedItem = bar.selectedItem;
        if (selectedItem) {
            NSUInteger index = [bar.items indexOfObject:selectedItem];
            if (index != NSNotFound) selected = (NSInteger)index;
        }
        NSUInteger slots = MIN(count, (NSUInteger)5);
        if (selected >= (NSInteger)slots) selected = (NSInteger)slots - 1;
        CGFloat slotWidth = CGRectGetWidth(bar.bounds) / (CGFloat)slots;
        slot = CGRectMake(slotWidth * (CGFloat)selected, 0, slotWidth, CGRectGetHeight(bar.bounds));
    }

    CGFloat height = MAX(capsule.size.height - 10.0, 30.0);
    CGFloat width = MIN(slot.size.width - 10.0, 74.0);
    if (width < 44.0) width = MAX(slot.size.width - 6.0, 36.0);

    return CGRectMake(CGRectGetMidX(slot) - width / 2.0,
                      CGRectGetMinY(capsule) + (capsule.size.height - height) / 2.0,
                      width,
                      height);
}

static void TBTUpdatePill(UITabBar *bar, BOOL animated, BOOL reposition) {
    UIView *pill = TBTEnsurePill(bar);
    if (!pill) return;

    CGFloat scale = TBTBarScale(bar);
    CGRect target = reposition ? TBTPillFrame(bar) : pill.frame;
    if (reposition && (CGRectIsNull(target) || target.size.width <= 1.0)) {
        pill.hidden = YES;
        return;
    }

    pill.hidden = NO;

    UITraitCollection *traits = bar.traitCollection;
    UIColor *border = [[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.10];
        return [UIColor colorWithWhite:0.0 alpha:0.05];
    }] resolvedColorWithTraitCollection:traits];

    pill.layer.cornerRadius = MAX(target.size.height, 0.0) / 2.0;
    pill.layer.borderWidth = 0.5 / scale;
    pill.layer.borderColor = border.CGColor;

    if (!reposition || CGRectEqualToRect(pill.frame, target)) return;

    if (!animated || pill.superview == nil) {
        pill.frame = target;
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:(UIViewAnimationOptionBeginFromCurrentState |
                                 UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         pill.frame = target;
                     }
                     completion:nil];
}

void TBTUpdatePillAnimated(UITabBar *bar) {
    if (!bar) return;
    // 只有已经套上玻璃的底栏才有滑块，避免在未改造的底栏上凭空加视图
    if (!objc_getAssociatedObject(bar, &kTBTContainerKey)) return;
    TBTUpdatePill(bar, YES, YES);
}

BOOL TBTBlocksAppearanceChange(UITabBar *bar, UITabBarAppearance *appearance) {
    UITabBarAppearance *applied = objc_getAssociatedObject(bar, &kTBTAppearanceKey);
    return applied && appearance != applied;
}

#pragma mark - Glass

static void TBTInstallGlass(UITabBar *bar) {
    if (objc_getAssociatedObject(bar, &kTBTContainerKey)) return;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.backgroundColor = [UIColor clearColor];
    container.userInteractionEnabled = NO;
    container.accessibilityElementsHidden = YES;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.22f;
    container.layer.shadowRadius = 20.0f;
    container.layer.shadowOffset = CGSizeMake(0, 10.0f);

    UIVisualEffectView *effect = nil;
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        effect = [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
        effect.contentView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        // 毛玻璃：太透会在浅色 App 里直接消失，这里用薄材质 + 可见描边
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
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.03];
        return [UIColor colorWithWhite:1.0 alpha:0.06];
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

    CGRect capsule = TBTCapsuleFrame(bar);
    container.frame = capsule;
    effect.frame = container.bounds;

    UIView *sheen = [effect.contentView viewWithTag:0x7B27];
    sheen.frame = effect.bounds;

    CGFloat radius = capsule.size.height / 2.0;
    effect.layer.cornerRadius = radius;
    container.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:container.bounds
                                                           cornerRadius:radius].CGPath;

    CGFloat scale = TBTBarScale(bar);
    UITraitCollection *traits = bar.traitCollection;
    // 浅色内容上必须有一条可见的细边，否则整个胶囊会“消失”在白色背景里
    UIColor *border = [[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) return [UIColor colorWithWhite:1.0 alpha:0.22];
        return [UIColor colorWithWhite:0.0 alpha:0.18];
    }] resolvedColorWithTraitCollection:traits];

    effect.layer.borderWidth = 0.75 / scale;
    effect.layer.borderColor = border.CGColor;

    NSValue *last = objc_getAssociatedObject(bar, &kTBTCapsuleFrameKey);
    BOOL geometryChanged = !last || !CGRectEqualToRect(last.CGRectValue, capsule);
    if (geometryChanged) {
        objc_setAssociatedObject(bar, &kTBTCapsuleFrameKey,
                                 [NSValue valueWithCGRect:capsule],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    TBTUpdatePill(bar, NO, geometryChanged);
}

#pragma mark - Appearance

static void TBTApplyAppearance(UITabBar *bar) {
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *current = bar.standardAppearance;
        UITabBarAppearance *applied = objc_getAssociatedObject(bar, &kTBTAppearanceKey);
        if (!applied || current != applied) {
            if (!applied) {
                if (current) {
                    objc_setAssociatedObject(bar, &kTBTSavedStandardKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                if (@available(iOS 15.0, *)) {
                    UITabBarAppearance *scroll = bar.scrollEdgeAppearance;
                    if (scroll) {
                        objc_setAssociatedObject(bar, &kTBTSavedScrollKey, scroll, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                }
                UIImage *indicator = bar.selectionIndicatorImage;
                if (indicator) {
                    objc_setAssociatedObject(bar, &kTBTSavedIndicatorKey, indicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

        // 只有滑块能定位时才隐藏系统底色，否则保留系统高亮，避免“什么都没有”
        UIImage *clear = TBTClearImage();
        CGRect pillTarget = TBTPillFrame(bar);
        BOOL hasSelectionTarget = !CGRectIsNull(pillTarget) && pillTarget.size.width > 1.0;
        if (hasSelectionTarget) {
            if (bar.selectionIndicatorImage != clear) {
                bar.selectionIndicatorImage = clear;
            }
        } else if (bar.selectionIndicatorImage == clear) {
            bar.selectionIndicatorImage = nil;
        }
    } else {
        if (!objc_getAssociatedObject(bar, &kTBTSavedImageKey)) {
            objc_setAssociatedObject(bar, &kTBTSavedImageKey, bar.backgroundImage ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(bar, &kTBTSavedShadowKey, bar.shadowImage ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        bar.backgroundImage = [UIImage new];
        bar.shadowImage = [UIImage new];
    }
}

#pragma mark - Public

/// 每进程只记一次“最近生效的 App”，面板里能看到，用来确认插件到底有没有跑起来。
static void TBTRecordStyledOnce(void) {
    static BOOL recorded = NO;
    if (recorded) return;
    recorded = YES;
    TBTRecordDiagnosticEvent(@"lastStyled");
}

void TBTStyleBar(UITabBar *bar) {
    if (!TBTShouldStyle(bar)) {
        TBTRestoreBar(bar);
        return;
    }

    TBTApplyAppearance(bar);
    TBTInstallGlass(bar);
    TBTUpdateGlass(bar);

    if (TBTSwipeEnabled()) {
        TBTSyncGestures(bar);
    } else {
        TBTRemoveGestures(bar);
    }

    TBTRecordStyledOnce();
}

void TBTRestoreBar(UITabBar *bar) {
    UIView *container = objc_getAssociatedObject(bar, &kTBTContainerKey);
    UITabBarAppearance *applied = objc_getAssociatedObject(bar, &kTBTAppearanceKey);
    if (!container && !applied) return;

    UIView *pill = objc_getAssociatedObject(bar, &kTBTPillKey);
    if (pill) [pill removeFromSuperview];
    objc_setAssociatedObject(bar, &kTBTPillKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(bar, &kTBTCapsuleFrameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

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

    id savedIndicator = objc_getAssociatedObject(bar, &kTBTSavedIndicatorKey);
    if (savedIndicator) bar.selectionIndicatorImage = savedIndicator;
    objc_setAssociatedObject(bar, &kTBTSavedIndicatorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id savedImage = objc_getAssociatedObject(bar, &kTBTSavedImageKey);
    if (savedImage) bar.backgroundImage = (savedImage == [NSNull null]) ? nil : savedImage;
    objc_setAssociatedObject(bar, &kTBTSavedImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id savedShadow = objc_getAssociatedObject(bar, &kTBTSavedShadowKey);
    if (savedShadow) bar.shadowImage = (savedShadow == [NSNull null]) ? nil : savedShadow;
    objc_setAssociatedObject(bar, &kTBTSavedShadowKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TBTWalkViews(UIView *view, void (^block)(UIView *)) {
    block(view);
    NSArray<UIView *> *subviews = view.subviews;
    for (UIView *sub in subviews) {
        TBTWalkViews(sub, block);
    }
}

void TBTRefreshAllBars(void) {
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
