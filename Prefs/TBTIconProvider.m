//
//  TBTIconProvider.m
//  TabBar26Prefs
//

#import "TBTIconProvider.h"

static NSCache<NSString *, UIImage *> *TBTIconCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 400;
    });
    return cache;
}

typedef UIImage *(*TBTIconFunc)(id, SEL, NSString *, NSInteger, CGFloat);

/// 系统图标服务（私有）：App Store / 巨魔 / 大多数越狱 App 都能取到。
static UIImage *TBTPrivateIcon(NSString *bundleID) {
    SEL selector = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:selector]) return nil;

    IMP imp = [UIImage methodForSelector:selector];
    TBTIconFunc func = (TBTIconFunc)imp;
    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale <= 0) scale = 3.0;

    for (NSInteger format = 2; format >= 0; format--) {
        UIImage *icon = nil;
        @try {
            icon = func([UIImage class], selector, bundleID, format, scale);
        } @catch (__unused NSException *exception) {
            icon = nil;
        }
        if (icon) return icon;
    }
    return nil;
}

/// App 包里散装的 png（越狱 App 常见）
static UIImage *TBTBundleIcon(NSString *bundlePath) {
    if (bundlePath.length == 0) return nil;

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                          [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
    NSMutableArray<NSString *> *names = [NSMutableArray array];

    id icons = info[@"CFBundleIcons"];
    if ([icons isKindOfClass:[NSDictionary class]]) {
        id primary = ((NSDictionary *)icons)[@"CFBundlePrimaryIcon"];
        if ([primary isKindOfClass:[NSDictionary class]]) {
            id files = ((NSDictionary *)primary)[@"CFBundleIconFiles"];
            if ([files isKindOfClass:[NSArray class]]) {
                [names addObjectsFromArray:(NSArray *)files];
            }
        }
    }
    id iconFile = info[@"CFBundleIconFile"];
    if ([iconFile isKindOfClass:[NSString class]]) {
        [names addObject:iconFile];
    }
    [names addObjectsFromArray:@[ @"Icon-60", @"AppIcon60x60", @"Icon" ]];

    for (NSString *raw in [names reverseObjectEnumerator]) {
        if (![raw isKindOfClass:[NSString class]] || raw.length == 0) continue;
        NSString *base = raw;
        if (base.pathExtension.length > 0) base = base.stringByDeletingPathExtension;
        for (NSString *suffix in @[ @"@3x.png", @"@2x.png", @".png" ]) {
            NSString *file = [base stringByAppendingString:suffix];
            UIImage *image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:file]];
            if (image) return image;
        }
    }
    return nil;
}

static UIImage *TBTResizedIcon(UIImage *image) {
    CGSize size = CGSizeMake(29.0, 29.0);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    }];
}

UIImage *TBTIconForApp(TBTAppInfo *app) {
    if (app.bundleIdentifier.length == 0) return nil;

    NSCache *cache = TBTIconCache();
    UIImage *cached = [cache objectForKey:app.bundleIdentifier];
    if (cached) return cached;

    UIImage *icon = TBTPrivateIcon(app.bundleIdentifier);
    if (!icon) icon = TBTBundleIcon(app.bundlePath);
    if (!icon) return nil;

    icon = TBTResizedIcon(icon);
    [cache setObject:icon forKey:app.bundleIdentifier];
    return icon;
}
