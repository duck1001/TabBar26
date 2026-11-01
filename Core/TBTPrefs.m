//
//  TBTPrefs.m
//  TabBar26
//
//  注入端读取偏好。沙盒里的 App 读不到 jbroot 的文件时，退回 cfprefsd / 文件两条路。
//

#import "TBTShared.h"
#import "TBTNotify.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

NSString *const TBTDomain = @"com.milkway.tabbar26";
NSString *const TBTPrefsChangedNotification = @"com.milkway.tabbar26/prefsChanged";

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

BOOL TBTEnabledForBundle(NSString *bundleID) {
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

BOOL TBTSwipeEnabled(void) {
    NSDictionary *prefs = TBTLoadPrefs();
    NSNumber *value = prefs[@"swipeEnabled"];
    return value ? [value boolValue] : YES;
}

void TBTRecordDiagnosticEvent(NSString *prefix) {
    if (prefix.length == 0) return;
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier ?: @"?";

    CFStringRef domain = (__bridge CFStringRef)TBTDomain;
    NSString *appKey = [prefix stringByAppendingString:@"App"];
    NSString *atKey = [prefix stringByAppendingString:@"At"];
    CFPreferencesSetAppValue((__bridge CFStringRef)appKey, (__bridge CFStringRef)bundleID, domain);
    CFPreferencesSetAppValue((__bridge CFStringRef)atKey, (__bridge CFPropertyListRef)@(CFAbsoluteTimeGetCurrent()), domain);
    CFPreferencesAppSynchronize(domain);

    // notify 的 state 在沙盒之外，面板一定能读到
    NSString *notifyName = [@"com.milkway.tabbar26." stringByAppendingString:prefix];
    TBTNotifyReport(notifyName, TBTNotifyHash(bundleID));
    TBTNotifyReport([notifyName stringByAppendingString:@"At"], (uint64_t)[[NSDate date] timeIntervalSince1970]);
}
