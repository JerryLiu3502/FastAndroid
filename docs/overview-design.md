# FastAndroid 概要设计说明书

| 项 | 内容 |
|----|------|
| 文档版本 | v1.0 |
| 日期 | 2026-06-06 |
| 适用范围 | FastAndroid 主壳 App 及 `fastFramework`/`baselib`/`libnetwork` 模块 |
| 读者对象 | 参与维护/扩展本工程的开发者 |
| 性质 | 对**现有工程**的逆向架构梳理（非新需求设计） |

> 本文为概要（high-level）设计，聚焦总体架构、模块职责、关键链路与扩展规范；不下沉到类级详细设计。

---

## 1. 项目概述与定位

FastAndroid 是一个 Android **技术演示 / 知识点练习型工程**（learning playground），不是线上产品。其形态为：

- **一个主壳 App**：通过 `SplashActivity`（LAUNCHER）→ `MainActivity` 进入，由 `DemoListFragment` / `JetPackDemoFragment` / `KotlinDemoListFragment` 等列表页导航，进入 **80+ 个相互独立的 demo**，每个 demo 对应一个知识点的可运行示例。
- **一套自研框架层**（`fastFramework`）：为 demo 提供 UI 基类、组件化、启动优化、性能监控等通用能力。
- **少量"带网络的实战页"**（`home`/`article`）：演示完整的 MVVM + Retrofit 数据流。

设计哲学：**新增功能 = 在 `demo/` 下新建子包 + 在对应列表 Fragment 注册入口**，而非改动公共主流程。

---

## 2. 设计目标与非目标

**目标**
- 用最小耦合承载大量互不干扰的知识点 demo，单个 demo 可独立运行、独立失败而不影响主壳。
- 框架能力（基类、组件、监控）下沉复用，demo 只关注知识点本身。
- 工程化统一：依赖、版本、插件集中管理，构建可复现。

**非目标**
- 不追求生产级稳定性、完整测试覆盖、向后兼容。
- demo 之间不要求一致的架构风格（同一能力常有 MVVM/MVI/RxJava/Flow/协程多种实现并存，本身即"对比学习"的一部分）。

---

## 3. 总体架构

### 3.1 分层与模块依赖

```
            ┌─────────────────────────────────────────────┐
            │                    app                        │
            │  主壳 + 80+ demo + home/article 实战页         │
            │  com.apache.fastandroid                       │
            └───────────────┬───────────────┬──────────────┘
                            │ depends on    │
            ┌───────────────▼──────┐  ┌─────▼──────────────┐
            │    fastFramework      │  │     libnetwork      │
            │ UI 基类/组件化/启动优化 │  │  Retrofit 网络封装   │
            │ /性能监控              │  │                     │
            │ com.tesla.framework   │  │ com.apache.         │
            │ com.optimize          │  │ fastandroid.network │
            │ com.tencent.lib       │  └─────────────────────┘
            └───────────┬──────────┘
                        │ depends on
            ┌───────────▼──────────┐
            │       baselib         │
            │ 更底层基类 Activity/    │
            │ Fragment、通用 UI/Adapter│
            │ com.apache.fastandroid.artemis │
            └──────────────────────┘
```

依赖方向（单向，不得反向）：`app → fastFramework / baselib / libnetwork`，`fastFramework → baselib`。
`settings.gradle` 当前仅启用 `app`、`baselib`、`fastFramework`、`libnetwork` 四个模块，其余历史模块均被注释。

### 3.2 架构风格

工程不强制统一架构，但实战页与 demo 中体现的主要模式有：

| 模式 | 体现位置 | 说明 |
|------|----------|------|
| MVVM | `home/HomeViewModel` + LiveData + `switchMap` | 首页 Feed 主链路 |
| MVI | `demo/mvi` + `fastFramework/component/mvicore` + `viewstate` | 单向数据流演示 |
| Repository | `HomeReporsitoryKt`、`jetpack/reporsity`、`datasource` | 数据源抽象 |
| DI（Hilt） | `@HiltAndroidApp`、`jetpack/hit` | 依赖注入演示 |
| 组件化（ApplicationLike） | `fastFramework/applike`（`FApplication`/`IApplicationLike`） | 模块化启动 |

---

## 4. 模块职责

### 4.1 app（主壳 + 全部 demo）
- 包名 `com.apache.fastandroid`，Application 入口 `app/FastApplication`（`@HiltAndroidApp`，继承 baselib 的 `ComApplication`）。
- 关键子包：
  - `demo/`：按知识点分子包（`mvi`、`paging`、`room`、`rxjava`、`designmode`、`customview`、`performance` 等 50+ 子包）。
  - `jetpack/`：Jetpack/协程/Flow 专题（`coroutine`、`flow`、`livedata`、`navigation`、`workmanager`、`hit`(Hilt) 等）。
  - `home/`、`article/`：带网络的实战列表页与详情页。
  - 其余：`app`(启动/Application)、`base`、`ui`、`widget`、`crash`、`aop`、`startintent` 等支撑包。

### 4.2 fastFramework（自研框架层）
命名空间 `com.tesla.framework` / `com.optimize` / `com.tencent.lib`。是大多数 demo 的基类与能力来源：
- `ui/`：UI 基类（如 `BaseDataBindingFragment`、`BaseBindingFragment`、`BaseListFragment`）。
- `applike/`：组件化启动（`FApplication`、`IApplicationLike`）。
- `component/`：50+ 通用组件（`mvicore`、`viewstate`、`di`、`eventbus`、`crashreporter`、`imageloader`、`logger`、`startup`、`storage`、`keyboardvisibilityevent` 等）。
- `com/optimize/performance/launchstarter/`：**启动优化**任务调度框架（task 有向图调度、排序、统计）。
- `performance/`：**卡顿与内存监控**——`takt`（FPS）、`watchdog`（卡顿/ANR）、`omagnifier`（内存放大镜）。
- `common/util`、`kt/`、`ext/`：通用工具与 Kotlin 扩展（如 `LaunchTimer`、`CommonUtil`、`buildSpannableString`）。

### 4.3 baselib（基础库）
命名空间 `com.apache.fastandroid.artemis`。更底层的基类 Activity/Fragment 与通用 UI/Adapter，被 fastFramework 与 app 复用（`ComApplication` 即来自此层）。

### 4.4 libnetwork（网络层）
命名空间 `com.apache.fastandroid.network`。Retrofit 封装，子包：
- `api/`：Retrofit 接口（`ApiService`、`FlowApiService` 等，详见 `docs/api.md`）。
- `retrofit/`：`RetrofitFactory`、转换器。
- `calladapter/`：自定义 CallAdapter——`NetworkResult`、`ApiResult`、LiveData CallAdapter。
- `interceptor/`：拦截器（含 `BaseUrlInterceptor` 多 host 动态路由）。
- `model/`、`model/result/`：统一响应包装（`BaseResponse`、`EmptyResponse` 等）。
- `exception/`、`ssl/`、`util/`：异常归一、SSL、常量（`ApiConstant.BASE_URL` 等）。

> 改动网络数据流时通常需同步 `model` + `calladapter` + `api` 三处。

---

## 5. 应用启动流程

```
SplashActivity (LAUNCHER)
      │
      ▼
FastApplication.onCreate()
  ├─ LeakCanary / ProcessPhoenix 进程判断（非主进程直接 return）
  ├─ 初始化 context/instance、DatabaseHelper、AppViewModelStore
  ├─ LaunchTimer 记录启动耗时
  ├─ Initiator.init(this)  ← 启动任务编排（配合 launchstarter）
  └─ ApiHelper / 各 Repository 懒加载
      │
      ▼
MainActivity（主壳）
      │
      ▼
DemoListFragment / JetPackDemoFragment / KotlinDemoListFragment …
      │  点击列表项
      ▼
进入具体 demo（Activity / Fragment）
```

启动期由 `com/optimize/performance/launchstarter` 做任务有向图调度，`LaunchTimer` + `performance/takt` 等度量首帧（如 `ArticleAdapter` 中 `LaunchTimer.endRecord("Feed Show")` 标记 Feed 首次可见）。

---

## 6. 典型业务数据流：首页 Feed（MVVM 实战）

```
HomeFragment ──observe──► HomeViewModel.articleList: LiveData<Result<List<Article>>>
   │                            ▲
   │ refresh()/loadMore()       │ switchMap(_forceUpdate)
   ▼                            │
HomeViewModel.onRefreshData() ──┤
   │  viewModelScope.launch     │
   │   ├─ async { loadTopArticle() }  ┐ 并行
   │   └─ async { loadHotData() }     ┘
   │           │
   │           ▼  HomeReporsitoryKt
   │           ▼  libnetwork: ApiService（Retrofit/协程）
   │           ▼  BaseResponse<...> → 解包
   │   convertToArticle(ArticleApi) → Article（含预解析 displayTitle）
   ▼
_articleList.postValue(Result.success(list))
   │
   ▼
ArticleAdapter（BaseQuickAdapter + stableIds + DataBinding）渲染
```

要点：网络请求在 `viewModelScope` 内并行发起；服务端实体 `ArticleApi` 经 `convertToArticle` 转为 UI 实体 `Article`；列表用 BRVAH 的 `BaseQuickAdapter` + stable ids 复用。

---

## 7. 网络层设计

- **统一入口**：`RetrofitFactory.create(...)`，默认 `baseUrl = ApiConstant.BASE_URL`（玩 Android）；支持运行时传入 baseUrl（GitHub、Album 等）。
- **多 host 路由**：`BaseUrlInterceptor` 依据请求 `Base-Url` Header 动态改写 host（如把某些请求路由到 `api.github.com`）。
- **多返回范式并存**（对比学习）：同一类查询提供协程 `suspend`、RxJava `Observable/Single`、Flow、`Call` 等多种声明。
- **统一响应包装**：`BaseResponse<T>{data,errorCode,errorMsg}` 为主；另有自研 `NetworkResult`/`ApiResult` 与 Sandwich `ApiResponse` 演示不同错误处理风格。
- 详细端点清单见 `docs/api.md`。

---

## 8. 性能与监控

| 维度 | 实现 | 位置 |
|------|------|------|
| 启动优化 | 任务有向图调度（launchstarter） | `com/optimize/performance/launchstarter` |
| 启动耗时度量 | `LaunchTimer` / `TimeMonitorManager` | `fastFramework/common`、app |
| 帧率（FPS） | `takt` | `fastFramework/performance/takt` |
| 卡顿 / ANR | `watchdog` | `fastFramework/performance/watchdog` |
| 内存 | `omagnifier`（内存放大镜）、LeakCanary | `fastFramework/performance/omagnifier`、app |
| 崩溃 | `crashreporter` / `cockroach`（兜底）、`crash/` | `fastFramework/component`、app |

---

## 9. 构建工程化（重要约定）

- **依赖与插件集中在 `buildSrc/`（Kotlin）管理**：版本 `Versions.kt`、坐标 `Libs.kt`、模块路径 `Modules.kt`、插件 id `Plugins.kt`。新增依赖应改这些文件，不在各 `build.gradle` 硬编码字符串。
- **共享构建脚本**（根目录 `*.gradle`，`apply from:` 注入）：`playFlavor.gradle`（定义 `env` 维度 `free`/`prod` flavor）、`base_lib.gradle`（库模块 Java 8 / Kotlin JVM target）、`and_res_guard.gradle`（资源混淆）、`version*.gradle`。
- **自定义 Gradle 插件** `com.fastandroid.release`（位于 `Plugin/`，app 已 apply）。
- 构建组合 `<flavor><BuildType>`，如 `assembleFreeDebug`、`assembleProdRelease`。
- 前置：`local.properties` 配 `sdk.dir`；release 签名依赖根目录 `prod.properties`（不提交）。

> AI 校验循环：`tools/ai_optimize_loop.sh`（跑 check → 喂失败日志给 AI 修复 → 再跑 → 通过则自动 commit/push），默认 check 命令 `./gradlew :app:assembleDebug`。

---

## 10. 扩展规范（新增 demo 的标准动作）

1. 在 `app/.../demo/<知识点>/` 下新建子包，放该 demo 的 Activity/Fragment/相关类。
2. 继承 fastFramework/baselib 的合适基类（如 `BaseBindingFragment`、`BaseListFragment`）。
3. 在对应列表 Fragment（`DemoListFragment` / `JetPackDemoFragment` / `KotlinDemoListFragment`）注册入口项。
4. 若需网络：在 `libnetwork` 增加接口/模型，必要时同步 `calladapter`。
5. 新增依赖改 `buildSrc/Libs.kt`（+ `Versions.kt`），勿硬编码。
6. 不修改公共主流程（主壳导航、Application 初始化）以免影响其它 demo。

命名约定：类 `PascalCase`、方法/属性 `camelCase`、常量 `UPPER_SNAKE_CASE`、资源 `lower_snake_case`；包路径保持在模块既有命名空间下（尤其 `com.apache.fastandroid`）。代码风格可从 `config/fast_android_style.xml` 导入。

---

## 11. 质量、安全与风险

- **测试**：JVM 单测置于 `src/test`，仪器测试置于 `src/androidTest`；演示工程整体覆盖率低，改动网络/生命周期相关代码时建议补测。
- **敏感文件**：`sign/`、APK 归档、`prod.properties` 视为敏感，**勿提交**；密钥不入源码。
- **架构风险**：
  - 单一接口（如 `ApiService`）混合多 host 端点，可读性差，扩展时易混淆 base URL。
  - demo 风格不统一是有意为之，但对新人理解主链路有干扰——以 `home`/`article` 作为"标准实战"参考。
  - 大量历史模块在 `settings.gradle` 被注释，启用前需校验可编译性。

---

## 12. 附录：目录结构速查

```
FastAndroid/
├── app/                  主壳 + demo + 实战页（com.apache.fastandroid）
│   └── src/main/java/com/apache/fastandroid/
│       ├── app/          FastApplication、启动
│       ├── demo/         按知识点分子包（50+）
│       ├── jetpack/      Jetpack/协程/Flow 专题
│       ├── home/ article/ 网络实战页
│       └── ...           base/ui/widget/crash/aop/...
├── fastFramework/        自研框架（com.tesla.framework / com.optimize / com.tencent.lib）
│   └── .../framework/
│       ├── ui/ applike/ component/(50+) common/ kt/ ext/
│       ├── performance/  takt / watchdog / omagnifier
│       └── (com/optimize/performance/launchstarter)
├── baselib/              底层基类（com.apache.fastandroid.artemis）
├── libnetwork/           Retrofit 封装（com.apache.fastandroid.network）
│   └── .../network/      api/ retrofit/ calladapter/ interceptor/ model/ exception/ ssl/ util/
├── buildSrc/             Versions/Libs/Modules/Plugins（依赖与版本集中管理）
├── Plugin/               自定义 Gradle 插件 com.fastandroid.release
├── docs/                 项目文档（本文件、api.md 等）
├── tools/                ai_optimize_loop.sh 等脚本
└── *.gradle              playFlavor / base_lib / and_res_guard / version* 共享脚本
```

---

> 相关文档：网络接口清单见 `docs/api.md`；提交/分支/测试等协作规范见根目录 `AGENTS.md` 与 `CLAUDE.md`。
