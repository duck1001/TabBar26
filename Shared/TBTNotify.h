//
//  TBTNotify.h
//  TabBar26（注入端与面板共用）
//
//  跨进程诊断通道：notify(3) 的 state 全局可读，不依赖沙盒里的偏好文件，
//  用来确认「注入 / 生效」到底发生在哪个 App。
//

#import <Foundation/Foundation.h>

uint64_t TBTNotifyHash(NSString *string);
void TBTNotifyReport(NSString *name, uint64_t value);
uint64_t TBTNotifyRead(NSString *name);
