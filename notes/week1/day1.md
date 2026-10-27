# 第一周 Day 1：搭环境 + 认识 Flutter

> 日期：2026-10-27 ｜ 关联代码：[playground/](../../playground/)

## 1. 核心心智模型：Flutter 自己画每一个像素

- 原生：写 `TextView` / `UILabel`，由系统控件负责绘制。
- Flutter：写 `Text`，由 Flutter 自带的渲染引擎 **Impeller**（早期是 Skia）直接画在一块画布上。
  - Android 上它只是 `FlutterActivity` 里的一个 Surface；
  - iOS 上它只是一个 `FlutterViewController`。

由此带来的影响：

| 现象 | 原因 |
|---|---|
| 两端 UI 像素级一致 | 不依赖系统控件 |
| "原生感"要靠 Material / Cupertino 组件模仿 | 同上 |
| 嵌入原生 View（地图、WebView）要用 PlatformView | Flutter 画布里本来没有原生 View（第 6 周） |
| 调用蓝牙、相机等要走 Platform Channel | Dart 和原生代码在不同的层（第 6 周） |

## 2. 三种编译模式

| 模式 | 编译方式 | 用途 |
|---|---|---|
| Debug | JIT | 开发，支持热重载；**性能慢，不能用来评估性能** |
| Profile | AOT | 接近 release 的性能，可以连 DevTools 做性能分析 |
| Release | AOT 编译成机器码 | 正式发布 |

## 3. 环境安装要点（Windows）

1. Flutter SDK 放在**无空格、无中文**的路径，例如 `D:\Programs\flutter`。
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable D:\Programs\flutter
   ```
2. 用户环境变量：
   - `Path` 加上 `D:\Programs\flutter\bin`
   - `ANDROID_HOME` = Android SDK 路径（本机是 `D:\ProgramFiles\Sdk`）
   - 国内网络可选：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
   - ⚠️ 不要用 `setx PATH ...`，它会把 PATH 截断到 1024 个字符。
3. Android Studio → SDK Tools 里勾选 **Android SDK Command-line Tools**。
4. 安装 Flutter 插件（Android Studio / VS Code）。
5. **新开一个终端**，然后运行 `flutter doctor` 和 `flutter doctor --android-licenses`。
   - Windows 上 **Visual Studio 一项报 ✗ 可以忽略**，它只在开发 Windows 桌面应用时需要。

## 4. 工程结构和原生的对照

| Flutter | Android | iOS |
|---|---|---|
| `lib/main.dart` | `MainActivity` + 业务代码 | `AppDelegate` + 业务代码 |
| `pubspec.yaml` | `build.gradle` 里的 dependencies | `Podfile` / `Package.swift` |
| `flutter pub get` | Gradle Sync | `pod install` |
| `android/` | 一个完整的 Android 壳工程 | — |
| `ios/` | — | 一个完整的 Xcode 壳工程 |
| `test/` | `src/test` | XCTest target |

`android/.../MainActivity.kt` 只是继承了 `FlutterActivity`，里面几乎是空的。

## 5. 热重载 vs 热重启 ⭐

| 操作 | Android Studio | 终端 `flutter run` | VS Code |
|---|---|---|---|
| 热重载 Hot Reload | ⚡ 按钮 / `Ctrl + \` / 保存文件 | `r` | 保存 / `Ctrl + F5` |
| 热重启 Hot Restart | 🔄 按钮 / `Ctrl + Shift + \` | `R` | `Ctrl + Shift + F5` |
| 完全重新运行 | 停止后再运行 | `q` 退出后重新 `flutter run` | 停止后再运行 |

**热重载 = 保留所有 State 对象，替换代码，重新执行一遍 `build()`。**

- 写在 `build()` 里的东西（颜色、标题）会更新，**正因为它们不是状态**，只是每次 build 时根据代码生成的结果。
- 存在 State 对象里的数据（`_counter`）被保留下来。
- 可以这样记：`UI = build(state)`。热重载换掉的是 `build` 函数，`state` 保持不变。

**热重启 = 从 `main()` 重新运行整个 Dart 应用**，内存里的所有状态都会丢失。

**热重载不生效的情况**（必须热重启）：

- 修改了 `main()`
- 修改了全局变量、静态变量、字段的**初始值**（例如 `int _counter = 0` 改成 `100`）
- 修改了 `initState()` 里的逻辑

**热重启也不生效的情况**（必须停止后重新运行）：

- 修改了原生代码（`MainActivity.kt`、`AppDelegate.swift`）
- 修改了 `AndroidManifest.xml` 或 `Info.plist`
- 新增了带原生代码的插件

> 📝 自查：我一开始的理解是"热重载更新了状态"，这是错的。正确的说法是"**保留状态，只更新代码**"。

## 6. 踩坑记录：Android Studio 一直卡在 `assembleDebug`

- **现象**：第一次运行时一直显示 `Running Gradle task 'assembleDebug'...`，没有任何报错。
- **原因**：Flutter 工程要求 NDK `28.2.13676358`（来自 `ndkVersion = flutter.ndkVersion`），本机只装了 25.1。AGP 尝试自动下载，失败后（`Package ndk not found`）一直挂着，没有退出。
- **为什么纯 Dart 的 App 也需要 NDK**：AGP 打包时要用 NDK 的工具处理 `libflutter.so` 这类 `.so` 文件，比如剥离调试符号。
- **怎么排查**：
  - Android Studio 用 `-q` 静默模式调用 Gradle，所以看不到进度。改用 `flutter run -v` 可以看到详细输出。
  - 也可以直接看 Gradle daemon 的日志：`%GRADLE_USER_HOME%\daemon\<版本>\daemon-*.out.log`。
- **解决**：SDK Manager → SDK Tools → 勾选 **Show Package Details** → NDK (Side by side) → 勾选 `28.2.13676358`。
  - 如果下载完后还是报 `sdkmanager did not install NDK`，检查 `Sdk\ndk\28.2.13676358` 文件夹里是否只有 `.installer`。如果是，说明安装没完成，把文件夹删掉重新安装。
