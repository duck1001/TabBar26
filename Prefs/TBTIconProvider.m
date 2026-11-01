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

BOOL TBTIconIsBlank(UIImage *image) {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return NO;

    const size_t width = 8;
    const size_t height = 8;
    unsigned char pixels[width * height * 4] = {0};

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4,
                                                 space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return NO;

    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);

    for (size_t i = 0; i < width * height; i++) {
        unsigned char r = pixels[i * 4];
        unsigned char g = pixels[i * 4 + 1];
        unsigned char b = pixels[i * 4 + 2];
        unsigned char maxC = MAX(r, MAX(g, b));
        unsigned char minC = MIN(r, MIN(g, b));
        if (maxC < 235 || (maxC - minC) > 18) return NO;
    }
    return YES;
}

UIImage *TBTIconForApp(TBTAppInfo *app) {    if (app.bundleIdentifier.length == 0) return nil;

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
