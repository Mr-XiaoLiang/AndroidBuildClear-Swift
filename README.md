# AndroidBuildClear

一个原生 macOS 小工具，用来扫描并清理 Gradle 工程里的 `build` 产物目录。

界面从早先的 Compose Desktop 版本移植而来，改用 SwiftUI + AppKit 重写，界面走 macOS 26 的 Liquid Glass 分层：内容层平铺，玻璃只留给控件层。

## 功能

- 管理一组待扫描的根文件夹（添加 / 移除，走原生文件夹选择面板）
- 递归查找 Gradle 模块的 `build` 目录并列出，支持逐条勾选
- 批量删除已勾选的 `build` 目录，删除前有确认弹窗
- 文件夹清单持久化：重启 App 后仍在，且保留沙盒访问权限
- 工具栏计数（文件夹数量 | build 目录数量），点击即可全选 / 取消全选

### 扫描规则

一个目录被认定为 Gradle 模块根，需要**同时**满足：

1. 存在名为 `build` 的子目录；
2. 存在 `build.gradle` 或 `build.gradle.kts`。

命中之后会收录该 `build` 目录，并且**不再深入**它自己的 `build` 子目录（那里都是编译产物）。遍历过程会跳过隐藏目录（顺带避开 `.git`、`.gradle` 这类巨型目录），也不会跟随符号链接。

### 快捷键

| 快捷键 | 动作 |
| --- | --- |
| `⌘O` | 添加文件夹 |
| `⌘R` | 重新扫描 |
| `⌘⌫` | 删除已勾选的 build 目录 |

## 环境要求

- macOS 26.6 或更高（用到 Liquid Glass 相关 API 与 Icon Composer 的 `.icon` 图标格式）
- Xcode 26 或更高

## 构建与运行

用 Xcode 打开 `AndroidBuildClear.xcodeproj` 直接运行即可，或走命令行：

```bash
xcodebuild -project AndroidBuildClear.xcodeproj \
           -scheme AndroidBuildClear \
           -configuration Debug \
           -destination 'platform=macOS' \
           build
```

### 沙盒相关

App 开启了沙盒（`ENABLE_APP_SANDBOX = YES`），并且 `ENABLE_USER_SELECTED_FILES` 必须是 **`readwrite`** —— 只读权限下无法删除用户所选目录里的内容，功能会直接失效。

因为沙盒的存在，文件夹清单不能只存路径字符串（下次启动就没有访问权限了），而是存**安全作用域书签**（`URL.bookmarkData(options: .withSecurityScope)`），启动时解析并 `startAccessingSecurityScopedResource()`。

## 项目结构

```
AndroidBuildClear/
├── AndroidBuildClearApp.swift        入口：单窗口场景、菜单命令
├── Models/
│   └── FileItem.swift                FolderItem / BuildFileItem
├── Services/
│   ├── BuildFileScanner.swift        递归扫描 + 递归删除
│   ├── SecurityScopedBookmarks.swift 书签持久化与沙盒访问权
│   └── WorkspaceStore.swift          状态中枢（@Observable）
├── Views/
│   ├── ContentView.swift             根视图：分栏 + 工具栏
│   ├── AppBackdrop.swift             窗口底色光晕
│   ├── WindowChrome.swift            标题栏透明化，并上报工具栏高度
│   ├── ResizableSplitView.swift      可拖拽的左右分栏
│   ├── FolderPanelView.swift         左栏：文件夹清单
│   └── BuildFilePanelView.swift      右栏：build 目录清单 + 悬浮删除按钮
└── AppIcon.icon                      Icon Composer 图标
```

## 实现要点

记录几个踩过坑、改动时容易踩回去的地方。

**扫描判定要区分"子项名"和"子目录"。** `build.gradle` / `build.gradle.kts` 是**文件**，如果判定用的名字集合只收集目录，这两个名字永远进不去，判定会恒为假、一个都扫不出来。所以判定用全部子项名，遍历用目录列表，两者分开。

**耗时操作放后台。** 目录遍历和删除都跑在 `Task.detached` 里，主线程只负责更新 `@Observable` 的状态。扫描结束后会按当前的根文件夹列表过滤一次结果，避免扫描期间增删文件夹带来的脏数据。

**工具栏的忙碌态用"固定槽位 + 只切透明度"。** 不要把按钮标签写成 `if isBusy { ProgressView() } else { Label(...) }`：两个分支的固有尺寸不同，`NSToolbar` 会重新测量并整组重排，看起来就是"点一下抖一下"。正确做法是图标和转圈同时存在、尺寸固定，只切 `opacity`。

**工具栏项默认从左边排起。** `NSToolbar` 是从 leading 边依次摆放的，`.primaryAction` 只是个语义标签。要靠右得用 `ToolbarSpacer()`（弹性空格）把内容顶过去；相邻两组想分开，中间还得加一个 `ToolbarSpacer(.fixed)`，光靠分组边界系统仍会画成同一块玻璃。

**列表拉通整窗，靠隐形留白把内容压回工具栏下方。** 列表本身忽略安全区、铺满窗口上下沿（这样内容能滚到工具栏底下，玻璃才有东西可折射，滚动区的裁剪边界也退到窗口外沿）；平时的留白由 `safeAreaInset` 塞一个 `Color.clear` 提供，高度取 `WindowChrome` 从 `NSWindow` 量出来的工具栏高度，不写死。

**不要给滚动列表配常驻表头。** 常驻表头要么得给背景（在渐变窗口上就是几块突兀的灰条），要么滚上来的行会糊在标题文字后面，两种都难看。所以计数放在了常驻的工具栏里，列表保持纯净。

## 许可

[MIT](LICENSE) © 2026 Mr-XiaoLiang
