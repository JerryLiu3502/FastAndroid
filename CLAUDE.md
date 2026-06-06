# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在本仓库中工作时提供指引。规则若与根目录 `AGENTS.md` 冲突，以用户当前明确要求 > 本文件 > `AGENTS.md` 的顺序裁决。

> 说明：本项目是 Android / Gradle 工程，**没有 `package.json`**；下文"常用命令"以 Gradle 为准。

---

## 1. 项目简介

FastAndroid 是一个 Android **技术演示 / 知识点练习型工程**（learning playground），**不是线上产品**。

- 一个主壳 App：`SplashActivity`（LAUNCHER）→ `MainActivity`，由列表页（`DemoListFragment` / `JetPackDemoFragment` / `KotlinDemoListFragment` 等）导航进入 **80+ 个相互独立的可运行 demo**，每个 demo 对应一个知识点。
- 定位是"对照学习"：同一能力常并存 MVVM / MVI / RxJava / Flow / 协程 等多种实现，差异是有意为之。
- 扩展范式：**在 `demo/` 下新建子包 + 在对应列表 Fragment 注册入口**，而非修改公共主流程。

---

## 2. 技术栈

| 维度 | 选型 |
|------|------|
| 语言 | Kotlin + Java 混用 |
| SDK | `applicationId com.apache.fastandroid`，compileSdk 30 / minSdk 26 / targetSdk 30（见 `buildSrc/AndroidConfig.kt`） |
| UI | DataBinding / ViewBinding、RecyclerView（BRVAH `BaseQuickAdapter`） |
| 架构 | MVVM、MVI（`mvicore` + `viewstate`）、Repository、Hilt（DI，`@HiltAndroidApp`） |
| 异步 | Kotlin 协程 / Flow、RxJava3 |
| 网络 | Retrofit + 自定义 CallAdapter（`NetworkResult` / `ApiResult` / LiveData），base URL 见 `ApiConstant` |
| 监控 | launchstarter（启动优化）、takt（FPS）、watchdog（卡顿）、omagnifier（内存）、LeakCanary |
| 构建 | Gradle 多模块 + `buildSrc`（Kotlin）集中管理依赖/版本/插件；flavor 维度 `env` = `free` / `prod` |
| 测试 | JUnit4、Robolectric（已在 Libs 中）、androidx.test；**jacoco 未配置**（无法直接出覆盖率报告） |
| 数据库/认证/部署 | Room 等以 demo 形式出现；无统一后端/认证/线上部署（演示工程，**待确认**是否需要） |

---

## 3. 核心目录结构

```
app/            主壳 + 全部 demo（com.apache.fastandroid）
  └ demo/       按知识点分子包（mvi/room/paging/rxjava/designmode/... 50+）
  └ jetpack/    Jetpack/协程/Flow 专题
  └ home/ article/  带网络的实战页（MVVM 标准参考链路）
  └ app/        FastApplication、启动初始化
fastFramework/  自研框架（com.tesla.framework / com.optimize / com.tencent.lib）
  └ ui/ applike/ component/(50+) performance/(takt/watchdog/omagnifier)
  └ com/optimize/performance/launchstarter  启动任务调度
baselib/        底层基类 Activity/Fragment、通用 UI/Adapter（com.apache.fastandroid.artemis）
libnetwork/     Retrofit 封装（com.apache.fastandroid.network）
  └ api/ retrofit/ calladapter/ interceptor/ model/ exception/ ssl/ util/
buildSrc/       Versions / Libs / Modules / Plugins / AndroidConfig（依赖与版本集中管理）
Plugin/         自定义 Gradle 插件 com.fastandroid.release
docs/           项目文档（overview-design.md / api.md / AI_LOOP.md / README.md）
tools/          ai_optimize_loop.sh 等脚本
*.gradle        playFlavor / base_lib / and_res_guard / version* 共享脚本
```

依赖方向（单向，不得反向）：`app → fastFramework / baselib / libnetwork`，`fastFramework → baselib`。
`settings.gradle` 仅启用 `app`、`baselib`、`fastFramework`、`libnetwork`，其余 include 多被注释，按需开启（**启用前需校验可编译性**）。

---

## 4. 常用命令

构建按 `<flavor><BuildType>` 组合（flavor 维度 `env`，取值 `free` / `prod`）：

```bash
./gradlew assembleFreeDebug                                  # 构建 free debug APK
./gradlew assembleProdRelease                                # prod release（混淆 + 资源混淆）
./gradlew :app:assembleDebug -x lint -x test --no-daemon     # 快速校验编译（AI 循环用的 check 命令）
./gradlew testFreeDebugUnitTest                              # 本地 JVM 单测
./gradlew connectedFreeDebugAndroidTest                      # 设备/模拟器仪器测试
./gradlew clean                                             # 清理构建产物
./gradlew archiveOutApks                                    # 拷贝 APK 到 outapk/archives
```

- 运行单个测试类：`./gradlew testFreeDebugUnitTest --tests "com.apache.fastandroid.XxxTest"`。
- 构建前需配置 `local.properties` 的 `sdk.dir`；release 签名依赖根目录 `prod.properties`（**不要提交**）。

---

## 5. 开发规范

**编码约定**
- Kotlin/Java 混用，包路径保持在模块既有命名空间下（尤其 `com.apache.fastandroid`）。
- 命名：类 `PascalCase`、方法/属性 `camelCase`、常量 `UPPER_SNAKE_CASE`、资源 `lower_snake_case`。
- 代码风格可从 `config/fast_android_style.xml` 导入 Android Studio。

**构建工程化（重要）**
- 依赖与插件统一在 `buildSrc/` 用 Kotlin 管理：版本 `Versions.kt`、坐标 `Libs.kt`、模块路径 `Modules.kt`、插件 id `Plugins.kt`。**新增依赖改这些文件，不在各 `build.gradle` 硬编码字符串**。
- 根目录 `*.gradle` 经 `apply from:` 注入：`playFlavor.gradle`（flavor）、`base_lib.gradle`（库模块 Java 8 / Kotlin JVM target）、`and_res_guard.gradle`（资源混淆）、`version*.gradle`。

**Git / 分支 / 提交**（详见 `AGENTS.md`）
- **默认在当前所在分支工作，不自动新建/切换分支**；分支由用户掌控，仅用户明确要求时才建/切。
- 提交遵循 conventional commits（`feat:`/`fix:`/`docs:`/`chore:` …）。
- **commit、push 到远端前必须取得用户明确授权**；禁止对公共分支强推或重写历史。

**测试**
- JVM 单测置于 `src/test`，仪器测试置于 `src/androidTest`；测试类按被测组件命名。
- 演示工程整体覆盖率低；改动网络/生命周期/分页等逻辑时建议补 JVM 单测（纯逻辑优先，如 `bean/PageInfo`）。

---

## 6. 修改代码时的注意事项

**先读这些文件再动手**
- 加依赖前：先看 `buildSrc/Libs.kt` + `Versions.kt`。
- 改网络数据流前：`libnetwork` 的 `model` + `calladapter` + `api` 通常需**同步改动**。
- 改首页/列表前：`home/HomeViewModel`、`home/ArticleAdapter`、`network/model/Article` 是一条耦合链路。

**易踩的坑**
- `network/model/Article` 是 `Serializable`，**不要往里塞 lambda/回调**（会序列化崩溃、污染 equals/hashCode）；交互回调走 Adapter 的 `listener` 回传。
- `libnetwork` 的 `ApiService` 把多个 host 的端点混在一个接口里，改 base URL 时注意 `BaseUrlInterceptor` 的 Header 路由，别张冠李戴。
- 改动应保持**最小范围**，不借机重构、换技术栈、动公共主流程或大面积格式化，以免影响其它 demo。
- `sign/`、APK 归档、`prod.properties` 视为敏感，**勿提交**；密钥不入源码。

**AI 自动优化循环**
- `tools/ai_optimize_loop.sh`：跑 check → 喂失败日志给 AI 修复 → 再跑 check → 通过则自动 commit/push，默认 check 为 `./gradlew :app:assembleDebug`。详见 `docs/AI_LOOP.md`。

---

## 7. 输出风格要求

- **默认中文**；先给结论，再给理由。
- 不臆造未读取/未验证的信息；不确定就标"待确认"，不编造文件、字段、命令。
- 改完按任务匹配做验证（编译/单测/最小复现），如实报告结果；验证失败要说清命令、关键错误、初步判断。
- 不奉承、不空洞客套；发现更大范围问题先记录建议，不擅自扩大任务范围。
- 涉及删除/覆盖/批量修改/推送等高风险操作，先说明风险与回滚方式并等待确认。
- 敏感信息用占位符（如 `YOUR_API_KEY`）。

---

## 8. 已知问题与处理（Known Issues）

- **AgentWeb 依赖坐标**：必须用 `com.github.Justson.AgentWeb:agentweb-core:4.1.9`（**不带 `v` 前缀**）。jitpack 上 `v4.1.9` 这个 tag 构建失败、拉不到（404）。见 `buildSrc/Libs.kt` 注释。
- **覆盖率报告**：未配置 jacoco，无法直接 `./gradlew jacoco...` 出覆盖率；缺口靠代码走查识别。
- **本地构建前置**：`local.properties`（`sdk.dir`）缺失会在 Gradle 配置阶段直接失败；该文件被 gitignore，不入库。
- **历史模块**：`settings.gradle` 中大量 include 被注释，启用前需逐个校验可编译性。

---

## 9. 相关文档与项目

| 资源 | 说明 |
|------|------|
| `README.md` | 项目入口：架构图、快速开始、模块一览 |
| `docs/overview-design.md` | 概要设计：架构、启动流程、数据流、构建工程化 |
| `docs/api.md` | 网络 API 端点清单与 base URL |
| `docs/AI_LOOP.md` | AI 自动优化循环说明 |
| `AGENTS.md` | 项目级协作规范（提交、分支与推送、测试、安全） |

> 这些文档按需读取即可，不必每次全量载入。

---

## 10. 维护

- 维护者：JerryLiu3502 · jerryliu.info@gmail.com（仓库 https://github.com/JerryLiu3502/FastAndroid）
- 团队成员 / 分工 / 排期：**待确认**（个人学习仓库，暂无团队信息）。

---
**Last Updated**: 2026-06-06
