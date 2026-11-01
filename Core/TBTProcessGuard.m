//
//  TBTProcessGuard.m
//  TabBar26
//
//  注入范围收口：只有 App 容器内的进程才处理。
//

#import "TBTShared.h"

BOOL TBTProcessEligible(void) {
    // 只缓存“是”，不缓存“否”：注入时机可能早于 mainBundle 就绪，
    // 早期的否判定不能把整个进程永久判死。
    static BOOL eligible = NO;
    if (eligible) return YES;

    NSBundle *main = [NSBundle mainBundle];
    NSString *bundleID = main.bundleIdentifier;
    NSString *path = main.bundlePath ?: @"";
    if (bundleID.length == 0) return NO;

    BOOL insideAppContainer =
        [path containsString:@"/Bundle/Application/"] ||
        [path containsString:@"/Applications/"] ||
        [path containsString:@"/var/jb/Applications/"];
    if (!insideAppContainer) return NO;

    // 设置 / SpringBoard 等系统宿主不处理
    if ([bundleID isEqualToString:@"com.apple.Preferences"] ||
        [bundleID isEqualToString:@"com.apple.springboard"] ||
        [bundleID hasPrefix:@"com.apple.Preferences."]) return NO;

    eligible = YES;
    return YES;
}
