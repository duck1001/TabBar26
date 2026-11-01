//
//  TBTNotify.m
//  TabBar26
//

#import "TBTNotify.h"
#import <notify.h>

uint64_t TBTNotifyHash(NSString *string) {
    uint64_t hash = 1469598103934665603ULL;   // FNV-1a 64
    const char *bytes = string.UTF8String;
    while (bytes && *bytes) {
        hash ^= (uint64_t)(unsigned char)(*bytes++);
        hash *= 1099511628211ULL;
    }
    return hash;
}

void TBTNotifyReport(NSString *name, uint64_t value) {
    if (name.length == 0) return;
    int token = 0;
    if (notify_register_check(name.UTF8String, &token) == NOTIFY_STATUS_OK) {
        notify_set_state(token, value);
        notify_cancel(token);
    }
    notify_post(name.UTF8String);
}

uint64_t TBTNotifyRead(NSString *name) {
    if (name.length == 0) return 0;
    int token = 0;
    uint64_t value = 0;
    if (notify_register_check(name.UTF8String, &token) == NOTIFY_STATUS_OK) {
        notify_get_state(token, &value);
        notify_cancel(token);
    }
    return value;
}
