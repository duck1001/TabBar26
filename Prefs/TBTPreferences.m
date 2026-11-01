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
