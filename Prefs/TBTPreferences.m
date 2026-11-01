//
//  TBTPreferences.m
//  TabBar26Prefs
//

#import "TBTPreferences.h"
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

NSString *TBTDiagnosticSummary(NSString *prefix) {
    NSString *appKey = [prefix stringByAppendingString:@"App"];
    NSString *atKey = [prefix stringByAppendingString:@"At"];

    id bundleID = TBTReadValue(appKey);
    if (![bundleID isKindOfClass:[NSString class]] || [bundleID length] == 0) {
        return @"尚未";
    }

    id stamp = TBTReadValue(atKey);
    NSString *time = @"";
    if ([stamp isKindOfClass:[NSNumber class]]) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:[stamp doubleValue]];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss";
        time = [NSString stringWithFormat:@" · %@", [formatter stringFromDate:date]];
    }
    return [NSString stringWithFormat:@"%@%@", bundleID, time];
}
