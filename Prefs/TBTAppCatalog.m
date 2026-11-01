//
//  TBTAppCatalog.m
//  TabBar26Prefs
//

#import "TBTAppCatalog.h"
#import <dlfcn.h>

@implementation TBTAppInfo
@end

static NSString *TBTJBPathString(NSString *path) {
    static char *(*jbrootFn)(const char *) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jbrootFn = (char *(*)(const char *))dlsym(RTLD_DEFAULT, "jbroot");
    });
    if (!jbrootFn) return nil;
    char *resolved = jbrootFn(path.fileSystemRepresentation);
    return resolved ? [NSString stringWithUTF8String:resolved] : nil;
}

static BOOL TBTIsRealAppPath(NSString *path) {
    if (path.length == 0) return NO;
    if ([path containsString:@"/PlugIns/"] ||
        [path containsString:@"/XPCServices/"] ||
        [path containsString:@"ViewService"] ||
        [path hasPrefix:@"/System/Library/"]) {
        return NO;
    }

    static NSArray<NSString *> *prefixes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSString *> *list = [NSMutableArray arrayWithArray:@[
            @"/var/containers/Bundle/Application/",
            @"/var/mobile/Containers/Bundle/Application/",
            @"/Applications/",
            @"/var/jb/Applications/",
        ]];
        NSString *jbApplications = TBTJBPathString(@"/Applications/");
        if (jbApplications.length > 0) [list addObject:jbApplications];
        prefixes = list;
    });

    for (NSString *prefix in prefixes) {
        if ([path hasPrefix:prefix]) return YES;
    }
    return NO;
}

static void TBTAddApp(NSMutableDictionary<NSString *, TBTAppInfo *> *map,
                      NSString *bundleID,
                      NSString *name,
                      NSString *path) {
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return;
    if (!TBTIsRealAppPath(path)) return;
    TBTAppInfo *existing = map[bundleID];
    if (existing) {
        if (existing.name.length == 0 && name.length > 0) existing.name = name;
        if (existing.bundlePath.length == 0 && path.length > 0) existing.bundlePath = path;
        return;
    }
    TBTAppInfo *app = [TBTAppInfo new];
    app.bundleIdentifier = bundleID;
    app.name = (name.length > 0) ? name : bundleID;
    app.bundlePath = path;
    map[bundleID] = app;
}

static NSString *TBTNameFromInfo(NSDictionary *info, NSString *fallback) {
    NSString *name = info[@"CFBundleDisplayName"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) name = info[@"CFBundleName"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) name = fallback;
    return name;
}

/// 扫描一层目录里的 .app
static void TBTScanFlat(NSString *directory, NSMutableDictionary<NSString *, TBTAppInfo *> *map) {
    if (directory.length == 0) return;
    NSArray<NSString *> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *item in items) {
        if (![item.pathExtension isEqualToString:@"app"]) continue;
        NSString *path = [directory stringByAppendingPathComponent:item];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
        NSString *bundleID = info[@"CFBundleIdentifier"];
        TBTAddApp(map, bundleID, TBTNameFromInfo(info, item.stringByDeletingPathExtension), path);
    }
}

/// 扫描 /var/containers/Bundle/Application/<UUID>/<App>.app
static void TBTScanContainers(NSString *directory, NSMutableDictionary<NSString *, TBTAppInfo *> *map) {
    if (directory.length == 0) return;
    NSArray<NSString *> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *item in items) {
        TBTScanFlat([directory stringByAppendingPathComponent:item], map);
    }
}

static void TBTCollectFromLaunchServices(NSMutableDictionary<NSString *, TBTAppInfo *> *map) {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        dlopen("/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
        workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    }
    if (!workspaceClass) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL defaultSelector = @selector(defaultWorkspace);
    SEL installedSelector = @selector(allInstalledApplications);
    SEL legacySelector = @selector(allApplications);
    id workspace = [workspaceClass respondsToSelector:defaultSelector] ? [workspaceClass performSelector:defaultSelector] : nil;

    NSMutableArray *applications = [NSMutableArray array];
    if ([workspace respondsToSelector:installedSelector]) {
        NSArray *installed = [workspace performSelector:installedSelector];
        if ([installed isKindOfClass:[NSArray class]]) [applications addObjectsFromArray:installed];
    }
    // allApplications 会带上系统 App（文件、快捷指令这类），allInstalledApplications 常常没有
    if ([workspace respondsToSelector:legacySelector]) {
        NSArray *legacy = [workspace performSelector:legacySelector];
        if ([legacy isKindOfClass:[NSArray class]]) [applications addObjectsFromArray:legacy];
    }
#pragma clang diagnostic pop

    for (id proxy in applications) {
        NSString *bundleID = nil;
        NSString *name = nil;
        NSURL *bundleURL = nil;
        @try {
            bundleID = [proxy valueForKey:@"applicationIdentifier"];
            name = [proxy valueForKey:@"localizedName"];
            bundleURL = [proxy valueForKey:@"bundleURL"];
        } @catch (__unused NSException *exception) {
            continue;
        }
        if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) continue;
        if (![name isKindOfClass:[NSString class]]) name = nil;
        NSString *path = [bundleURL isKindOfClass:[NSURL class]] ? bundleURL.path : nil;
        TBTAddApp(map, bundleID, name, path);
    }
}

NSArray<TBTAppInfo *> *TBTInstalledApps(void) {
    NSMutableDictionary<NSString *, TBTAppInfo *> *map = [NSMutableDictionary dictionary];

    // 1. LaunchServices：App Store / 巨魔 注册过的 App
    TBTCollectFromLaunchServices(map);

    // 2. 目录补齐：越狱商店装到 jbroot/Applications 的 App、以及 LS 没登记的
    TBTScanContainers(@"/var/containers/Bundle/Application", map);
    TBTScanContainers(@"/var/mobile/Containers/Bundle/Application", map);
    TBTScanFlat(@"/Applications", map);
    TBTScanFlat(@"/var/jb/Applications", map);

    NSString *jbApplications = TBTJBPathString(@"/Applications");
    if (jbApplications.length > 0) TBTScanFlat(jbApplications, map);

    NSMutableArray<TBTAppInfo *> *result = [NSMutableArray arrayWithCapacity:map.count];
    [map enumerateKeysAndObjectsUsingBlock:^(NSString *bundleID, TBTAppInfo *app, BOOL *stop) {
        [result addObject:app];
    }];
    [result sortUsingComparator:^NSComparisonResult(TBTAppInfo *a, TBTAppInfo *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return result;
}
