//
//  TBTProcessGuard.m
//  TabBar26
//
//  注入范围收口：只有 App 容器内的进程才处理。
//

#import "TBTShared.h"

BOOL TBTProcessEligible(void) {
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
