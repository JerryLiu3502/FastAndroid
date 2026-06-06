# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

FastAndroid 是一个 Android **技术演示 / 知识点练习型工程**（learning playground），不是线上产品。主壳 App 通过列表页（`DemoListFragment`、`JetPackDemoFragment`、`KotlinDemoListFragment` 等）导航进入 80+ 个独立 demo，每个 demo 对应一个知识点的可运行示例。新增功能时，遵循"在 `demo/` 下新建子包 + 在对应列表 Fragment 注册入口"的既有模式，而不是修改公共主流程。

## 常用命令

构建按 `<flavor><BuildType>` 组合，flavor 维度为 `env`，取值 `free` / `prod`：

```bash
./gradlew assembleFreeDebug                    # 构建 free debug APK
./gradlew assembleProdRelease                  # 构建 prod release（混淆 + 资源混淆）
./gradlew :app:assembleDebug -x lint -x test --no-daemon   # 快速校验编译（AI 循环用的 check 命令）
./gradlew testFreeDebugUnitTest                # 运行 app 的本地 JVM 单测
./gradlew connectedFreeDebugAndroidTest        # 运行设备/模拟器上的仪器测试
./gradlew clean                                # 清理构建产物
./gradlew archiveOutApks                       # 把生成的 APK 拷贝到 outapk/archives
```

运行单个测试类：`./gradlew testFreeDebugUnitTest --tests "com.apache.fastandroid.XxxTest"`。

构建前需配置 `local.properties` 的 `sdk.dir`。release 签名依赖根目录 `prod.properties`（不要提交）。

## 架构与模块依赖

Gradle 多模块，依赖方向 `app → fastFramework / baselib / libnetwork`：

- **app**：主壳 + 全部 demo，包名 `com.apache.fastandroid`。`demo/` 按知识点分子包；`jetpack/` 为 Jetpack/协程/Flow 专题；`home/` `article/` 为带网络的实战列表页。
- **fastFramework**（`com.tesla.framework` / `com.optimize` / `com.tencent.lib`）：自研框架层——UI 基类、`applike` 组件化、`launchstarter` 启动优化、`performance`（takt/watchdog/omagnifier 卡顿与内存监控）。这是大多数 demo 的基类来源。
- **baselib**（`com.apache.fastandroid.artemis`）：更底层的基类 Activity/Fragment 与通用 UI/Adapter。
- **libnetwork**（`com.apache.fastandroid.network`）：Retrofit 封装。关键子包：`calladapter`（自定义 `NetworkResult` / `ApiResult` / LiveData CallAdapter）、`interceptor`、`retrofit/convertor`、`exception`、`model/result`（统一响应包装）。改动网络数据流时通常需同步 `model` + `calladapter` + `api`。

## 构建工程化（重要约定）

- **依赖与插件统一在 `buildSrc/` 用 Kotlin 管理**：版本见 `Versions.kt`，依赖坐标见 `Libs.kt`，模块路径见 `Modules.kt`，插件 id 见 `Plugins.kt`。新增依赖应改这些文件，而不是在各 `build.gradle` 里硬编码字符串。
- 根目录的 `*.gradle` 是共享构建脚本，通过 `apply from:` 注入：`playFlavor.gradle`（定义 free/prod flavor）、`base_lib.gradle`（库模块的 Java 8 / Kotlin JVM target）、`and_res_guard.gradle`（资源混淆）、`version*.gradle`。
- `Plugin/` 下有自定义 Gradle 插件 `com.fastandroid.release`（app 已 apply）。
- `settings.gradle` 中只启用了 `app`、`baselib`、`fastFramework`、`libnetwork`；其余 include 多被注释，按需开启。

## 编码约定

- Kotlin/Java 混用，包路径保持在模块既有命名空间下（尤其 `com.apache.fastandroid`）。
- 代码风格可从 `config/fast_android_style.xml` 导入 Android Studio。
- 资源命名 `lower_snake_case`，常量 `UPPER_SNAKE_CASE`。

## AI 自动优化循环

`tools/ai_optimize_loop.sh` 实现"跑 check 命令 → 喂失败日志给 AI 修复 → 再跑 check → 通过则自动 commit/push"的循环，默认 check 命令为 `./gradlew :app:assembleDebug`。详见 `docs/AI_LOOP.md`。

## 其他

- 更详细的提交规范、测试放置位置等见根目录 `AGENTS.md`。
- `sign/`、APK 归档、`prod.properties` 视为敏感，勿提交。
