//
//  TBTPreferences.m
//  TabBar26Prefs
//

#import "TBTPreferences.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

NSString *const TBTPreferencesDomain = @"com.milkway.tabbar26";
NSString *const TBTPreferencesChangedNotification = @"com.milkway.tabbar26/prefsChanged";

static id TBTReadValue(NSString *key) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)TBTPreferencesDomain);
    return value ? (__bridge_transfer id)value : nil;
}

static void TBTWriteValue(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)TBTPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)TBTPreferencesDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)TBTPreferencesChangedNotification,
                                         NULL, NULL, true);
}

#pragma mark - Values

BOOL TBTGetEnabled(void) {
    NSNumber *value = TBTReadValue(@"enabled");
    return value ? [value boolValue] : YES;
}

void TBTSetEnabled(BOOL enabled) {
    TBTWriteValue(@"enabled", @(enabled));
}

NSInteger TBTGetScope(void) {
    NSNumber *value = TBTReadValue(@"scope");
    return value ? [value integerValue] : 0;
}

void TBTSetScope(NSInteger scope) {
    TBTWriteValue(@"scope", @(scope));
}

NSArray<NSString *> *TBTGetSelectedApps(void) {
    id value = TBTReadValue(@"selectedApps");
    if (![value isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if ([item isKindOfClass:[NSString class]]) [result addObject:item];
    }
    return result;
}

void TBTSetSelectedApps(NSArray<NSString *> *bundleIDs) {
    TBTWriteValue(@"selectedApps", bundleIDs ?: @[]);
}

#pragma mark - App list

@implementation TBTAppInfo
@end

static void TBTScanAppDirectory(NSString *directory, NSMutableDictionary<NSString *, NSString *> *map) {
    if (directory.length == 0) return;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSString *> *items = [manager contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *item in items) {
        if (![item.pathExtension isEqualToString:@"app"]) continue;
        NSString *path = [directory stringByAppendingPathComponent:item];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
        NSString *bundleID = info[@"CFBundleIdentifier"];
        if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) continue;
        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: item.stringByDeletingPathExtension;
        if (![name isKindOfClass:[NSString class]] || name.length == 0) name = bundleID;
        map[bundleID] = name;
    }
}

/// /var/containers/Bundle/Application/<UUID>/<App>.app
static void TBTScanContainerDirectory(NSString *directory, NSMutableDictionary<NSString *, NSString *> *map) {
    if (directory.length == 0) return;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSString *> *items = [manager contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *item in items) {
        NSString *path = [directory stringByAppendingPathComponent:item];
        TBTScanAppDirectory(path, map);
    }
}

NSArray<TBTAppInfo *> *TBTInstalledApps(void) {
    NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        dlopen("/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
        workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    }
    if (workspaceClass) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        SEL selector = NSSelectorFromString(@"allInstalledApplications");
        if ([workspace respondsToSelector:selector]) {
            NSArray *applications = [workspace performSelector:selector];
            for (id proxy in applications) {
                NSString *bundleID = nil;
                NSString *name = nil;
                @try {
                    bundleID = [proxy valueForKey:@"applicationIdentifier"];
                    name = [proxy valueForKey:@"localizedName"];
                } @catch (__unused NSException *exception) {
                    continue;
                }
                if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) continue;
                if (![name isKindOfClass:[NSString class]] || name.length == 0) name = bundleID;
                map[bundleID] = name;
            }
        }
    }

    if (map.count == 0) {
        TBTScanContainerDirectory(@"/var/containers/Bundle/Application", map);
        TBTScanAppDirectory(@"/Applications", map);
        TBTScanAppDirectory(@"/var/jb/Applications", map);
    }

    NSMutableArray<TBTAppInfo *> *result = [NSMutableArray arrayWithCapacity:map.count];
    [map enumerateKeysAndObjectsUsingBlock:^(NSString *bundleID, NSString *name, BOOL *stop) {
        TBTAppInfo *app = [TBTAppInfo new];
        app.bundleIdentifier = bundleID;
        app.name = name;
        [result addObject:app];
    }];
    [result sortUsingComparator:^NSComparisonResult(TBTAppInfo *a, TBTAppInfo *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return result;
}
