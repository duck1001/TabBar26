# TabBar26

iOS 26 风格的悬浮玻璃底栏（Liquid Glass Tab Bar），把 App 原生 `UITabBar` 换成悬浮胶囊玻璃样式。
仅 iOS 15–16 / arm64e / RootHide（roothide）环境，版本 0.0.1。

## 功能

- 原生底栏改为 iOS 26 的悬浮胶囊玻璃样式：细毛玻璃 + 描边 + 投影，标签图标保持原位。
- 选中项下方有一枚会滑动的圆角滑块（外胶囊 + 内滑块，弹簧动画），随点击 / 滑动切页移动。
- 两种生效范围，设置面板里切换：
  - **全部 App**：所有 App 的原生底栏生效。
  - **仅选中的 App**：只对「选择 App」里勾选的 App 生效。
- 应用列表合并 App Store、巨魔、越狱商店与系统 App，显示真实图标。
- 设置面板为 SF Symbols 图标风格，附带应用选择列表与搜索。
- 悬浮底栏上左右滑动切换相邻页面（可在面板关闭）；点按仍然交给系统 tab 按钮。
- 设置改动即时下发，不用注销设备。

## 避让 App 内部逻辑

这是实现时最在意的部分：

- **不改 frame、不动 safe area**：底栏的布局仍由系统负责，`hidesBottomBarWhenPushed` 的推入/推出动画、
  键盘避让、横竖屏切换都走原生逻辑，不接管。
- **不加手势、不拦截触摸**：玻璃容器 `userInteractionEnabled = NO`，命中测试仍然落在系统 tab 按钮上。
- **只处理真正的 `UITabBarController` 底栏**：自绘底栏、被 App 自己容器托管的 `UITabBar` 直接跳过。
- **保留 App 自己的 item 配色**：切换透明背景前备份 `UITabBarItemAppearance`，不会吃掉 App 定义的图标/文字颜色。
- **跳过设置 App 与 SpringBoard**，避免影响系统界面。
- 减少透明度（辅助功能）开启时自动退化为纯色背景。

## 安装

从 Actions 产物下载 `com.milkway.tabbar26_0.0.1_iphoneos-arm64.deb`，用 Sileo / Zebra / dpkg 安装，
设置 App 里会多出「TabBar26」入口。

```sh
dpkg -i com.milkway.tabbar26_0.0.1_iphoneos-arm64.deb
killall -9 SpringBoard Preferences
```

## 自行打包

仓库自带 GitHub Actions（macOS 15）工作流，push 到 `main` 或手动 `Run workflow` 即可出包。

本地构建（macOS + roothide/theos）：

```sh
make package FINALPACKAGE=1 \
  THEOS_PACKAGE_SCHEME=roothide \
  ARCHS=arm64e \
  TARGET=iphone:clang:16.5:15.0
```

## 代码结构

```
Tweak.xm                  hook 入口（UITabBar / UITabBarController）
Core/
  TBTShared.h             公用声明
  TBTPrefs.m              偏好读取（cfprefsd + 文件兜底）
  TBTProcessGuard.m       进程收口
  TBTTabBarUtils.m        底栏宿主判定
  TBTBarStyler.m          玻璃外观 + 内部滑块
  TBTSwipe.m              左右滑动切页
Prefs/
  TBTPreferences.m        偏好读写
  TBTAppCatalog.m         应用清单（App Store / 巨魔 / 越狱 / 系统）
  TBTIconProvider.m       应用图标
  TBTUI.m                 面板基类
  TBTRootController.m     主面板
  TBTScopeController.m    生效范围
  TBTAppsController.m     选择 App
```

## 已知限制

- 只支持 iOS 15–16、arm64e；RootHide 方案打包。
- 使用自绘底栏的 App（不基于 `UITabBar`）不会变化，这是刻意避让。
- 底栏保持系统原有高度，内容不会额外伸展到底栏下方（0.0.2 再考虑）。
