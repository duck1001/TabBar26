//
//  TBTSwipe.m
//  TabBar26
//
//  底栏左右滑动切页。手势只挂在底栏上，cancelsTouchesInView = NO，点按仍然走系统 tab 按钮。
//

#import "TBTSwipe.h"
#import "TBTShared.h"
#import <objc/runtime.h>

static char kTBTGesturesKey;

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
    // 索引必须能对得上，非标准宿主的底栏不动
    if (controller.tabBar != bar) return;

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

void TBTSyncGestures(UITabBar *bar) {
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

void TBTRemoveGestures(UITabBar *bar) {
    NSArray<UISwipeGestureRecognizer *> *recognizers = objc_getAssociatedObject(bar, &kTBTGesturesKey);
    if (!recognizers) return;
    for (UISwipeGestureRecognizer *swipe in recognizers) {
        [bar removeGestureRecognizer:swipe];
    }
    objc_setAssociatedObject(bar, &kTBTGesturesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
