//
//  TBTPreferences.m
//  TabBar26Prefs
//

#import "TBTPreferences.h"
#import "TBTAppCatalog.h"
#import "TBTNotify.h"
#import <CoreFoundation/CoreFoundation.h>

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

BOOL TBTGetSwipeEnabled(void) {
    NSNumber *value = TBTReadValue(@"swipeEnabled");
    return value ? [value boolValue] : YES;
}

void TBTSetSwipeEnabled(BOOL enabled) {
    TBTWriteValue(@"swipeEnabled", @(enabled));
}

#pragma mark - Diagnostics

static NSArray<TBTAppInfo *> *TBTDiagnosticApps(void) {
    static NSArray<TBTAppInfo *> *apps = nil;
    static CFAbsoluteTime stamp = 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (!apps || (now - stamp) > 5.0) {
        apps = TBTInstalledApps();
        stamp = now;
    }
    return apps;
}

NSString *TBTDiagnosticSummary(NSString *prefix) {
    // 1) notify state：跨进程，不受沙盒影响
    NSString *name = [@"com.milkway.tabbar26." stringByAppendingString:prefix];
    uint64_t hash = TBTNotifyRead(name);
    uint64_t stamp = TBTNotifyRead([name stringByAppendingString:@"At"]);
    if (hash != 0) {
        NSString *display = nil;
        for (TBTAppInfo *app in TBTDiagnosticApps()) {
            if (TBTNotifyHash(app.bundleIdentifier) == hash) {
                display = app.name;
                break;
            }
        }
        if (display.length == 0) {
            display = [NSString stringWithFormat:@"#%06llx", (unsigned long long)(hash & 0xFFFFFF)];
        }
        if (stamp > 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)stamp];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"HH:mm:ss";
            return [NSString stringWithFormat:@"%@ · %@", display, [formatter stringFromDate:date]];
        }
        return display;
    }

    // 2) 退回偏好域
    id bundleID = TBTReadValue([prefix stringByAppendingString:@"App"]);
    if ([bundleID isKindOfClass:[NSString class]] && [bundleID length] > 0) {
        return bundleID;
    }
    return @"尚未";
}
