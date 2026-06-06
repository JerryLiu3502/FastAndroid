# app 模块 Clean Code 审查报告（2026-06-06）

| 项 | 内容 |
|----|------|
| 日期 | 2026-06-06 |
| 范围 | app 模块核心维护代码（home / article / app 启动 + 本会话改动），demo 抽样 |
| 方法 | clean-code-reviewer 子 agent（只读），按 Clean Code 原则 |
| 性质 | 演示工程，下列问题为可读性/可维护性建议，非阻断 |

> 已按项目约定排除：多架构对照（MVVM/MVI/RxJava/Flow/协程并存）、Kotlin/Java 混用、demo 风格不统一——这些不计为缺陷。
> 跳过：第三方移植代码（`com/downloader`、`com/example/.../blueprints`、`com/android/example/github` 等）。

## 总览

- **整体 Clean Code 健康度：3 / 5**
- 问题统计：Critical 1 · High 4 · Medium 5 · Low 3
- 核心链路结构清晰，但「命名拼写、死代码、吞异常」是普遍且容易修的硬伤。

---

## High

### [High] 命名 — 类名/文件名拼写错误 `Reporsitory`（应为 `Repository`）
影响面：跨核心链路与多个 demo，11+ 文件
- `home/HomeReporsitoryKt.kt`（类 `HomeReporsitoryKt`）、`article/ArticleReporsitoryKt.kt`（类 `ArticleReporsitoryKt`）
- 引用方：`home/HomeViewModel.kt:18`（参数 `reporsitoryKt`）、`home/HomeModelFactory.kt`、`article/ArticleModelFactory.kt`、`article/ArticleViewModel.kt`、`demo/mvi/MviViewModel.kt:4`、`jetpack/flow/vm/FlowUserViewModel.kt`、`util/InjectorUtil.kt`、`demo/kt/coroutine/*` 等

问题：`Reporsitory` 拼写错误，`Repository` 是行业通用术语，搜索/补全/可读性全受影响；`Kt` 后缀是把语言编码进类名（Clean Code 反对编码式命名）。
原则：Intention-Revealing / Searchable Names，No Encodings。
建议：统一重命名为 `HomeRepository` / `ArticleRepository`（去 `Kt` 后缀），构造参数 `reporsitoryKt` → `repository`。IDE 重命名一次性带走全部引用与文件名。**最值得优先做的一次性清理。**

### [High] 错误处理 — 异常被 `printStackTrace()` 吞掉，无上下文/无上报（53 处）
- `home/HomeViewModel.kt:92-94`、`home/HomeReporsitoryKt.kt:27-29`、`jetpack/flow/vm/FlowUserViewModel.kt:39/49`、`jetpack/flow/basic/FlowBasicUsageFragment.kt:87/110/144` 等

```kotlin
} catch (e: Exception) {
    e.printStackTrace()
    _articleList.postValue(Result.failure(e))
}
```

问题：`printStackTrace()` 在生产无意义（不进日志系统）；`catch (e: Exception)` 过宽，会吞掉 `CancellationException`（协程里破坏结构化并发取消）。`HomeReporsitoryKt:27` 吞异常后转 `PageState.Error`，丢失类型信息。
原则：Provide Context with Exceptions，Don't Swallow Exceptions。
建议：改用项目已有的 `Logger.e(TAG, "load home article failed", e)`；协程内捕获排除 `CancellationException`（或捕获更具体异常）。`onRefreshData` 处 `Result.failure(e)` 已向上传，`printStackTrace` 冗余可删。

### [High] 结构 — `HomeViewModel` 两份等价的 `ArticleApi → Article` 转换（DRY）
`home/HomeViewModel.kt:120-137`（私有 `convertToArticle`）与 `:141-158`（顶层扩展 `ArticleApi.toArticle()`）字段映射完全一致。

问题：同一映射两份实现，改一处忘另一处必出 bug；`MviViewModel.kt:56` 用 `toArticle()`、`HomeViewModel` 内部用 `convertToArticle`，漂移风险已存在。
原则：DRY。
建议：删除 `convertToArticle`，`:87 / :107` 处统一调 `it.toArticle()`。

### [High] 函数 — `FastApplication` 启动方法职责过宽 / 嵌套偏深
`app/FastApplication.kt:118-136`（`getResources()`）、`onCreate:63-85`、`attachBaseContext:87-106`

问题：`getResources()` 把「字体缩放兜底」塞进 framework 重写方法（含 SDK 版本分支 + 副作用）；`onCreate` 混合进程判断、单例赋值、DB 初始化、计时、SP 初始化多职责。
原则：Single Responsibility / Functions Do One Thing。
建议：抽 `private fun forceDefaultFontScale(res: Resources)`；`onCreate` 进程短路判断抽 `private fun shouldSkipInit(): Boolean`。

---

## Medium

### [Medium] 死代码 — `FastApplication.taskRepository` 不可达的重复 `return`
`app/FastApplication.kt:174-175`
```kotlin
return DefaultTasksRepository(TasksLocalDataSource(taskDao), TasksLocalDataSource(taskDao))
return DefaultTasksRepository(TasksLocalDataSource(taskDao), TasksLocalDataSource(taskDao)) // 永不可达
```
问题：第 175 行恒不可达；同一 `taskDao` 当作两个 DataSource 传入，语义可疑。
建议：删第 175 行；复核两参数是否本应为 local + remote 两个源。

### [Medium] 注释 — 大段注释掉的死代码散落核心链路
`home/HomeFragment.kt:47/64/67/79-81/94`、`article/ArticleDetailActivity.kt:31/76-84/94-96`、`HomeViewModel.kt:28-30`（`_text` 未使用）
原则：Don't Comment Out Code（交给 VCS）。
建议：删除注释代码；`HomeViewModel._text` 无引用一并删。

### [Medium] 命名 — 含糊的 `handleXxx` 动词
`home/HomeFragment.kt:77 handleData`、`ArticleAdapter.kt:95/101/111 handleTitle/handleAuthor/handleCategory`
建议：`handleData` → `renderPagedArticles`/`submitArticles`；`handleTitle` → `resolveDisplayTitle`；`handleAuthor` → `formatAuthorLabel`；`handleCategory` → `formatCategory`。

### [Medium] 错误处理 — `HomeViewModel.loadMore()` 失败回调为空，静默吞错
`home/HomeViewModel.kt:103-117`，第二个 lambda（失败回调）体为空 `{ }`。
建议：失败回调至少 `Logger.e(...)`，并通过 `Result.failure(it)` 或专门加载状态通知 UI 结束 loadMore 动画。

### [Medium] 命名 — 资源/方法名拼写错误（非第三方）
`home/HomeFragment.kt:51 mBinding.recycleview`（应 `recyclerView`）、`:94` 注释 `no modelre`、`ArticleAdapter.kt:25` lambda 参数 `viwe`
建议：局部笔误（`viwe`→`view`、`modelre`→`more`）直接改；`recycleview` 系 layout id 历史命名、蔓延 60+ 文件，记录为后续统一项，新代码勿沿用。

---

## Low

- **[Low] 魔法字符串**：`article/ArticleDetailActivity.kt:49/55/100/101` 裸写 `"title"`/`"url"`。建议提 `companion` 常量 `KEY_TITLE`/`KEY_URL`，launch 与读取端共用。
- **[Low] 可空性**：`ArticleAdapter.handleTitle(article: Article?)` 接收可空但调用点恒非空（`convert` 回调里非空）。建议去掉可空与兜底，简化签名。
- **[Low] 单例样板重复**：`HomeReporsitoryKt.kt:54-64` 与 `ArticleReporsitoryKt.kt:24-37` double-check 单例几乎逐字复制，且 `HomeReporsitoryKt.instance` 缺 `@Volatile`（可见性隐患）。建议补 `@Volatile`；若引入 Hilt 作用域可去掉手写单例。

---

## 值得肯定（Good Practices）

- `demo/floo/WebActivity.java`（本会话改过）：scheme 白名单 + deeplink host 校验 + `url==null` 已 return 防崩，注释解释 WHY（攻击面）而非 WHAT。
- `HomeViewModel.onRefreshData():62-101`：`async{}` 并行两请求再 `await`，注释点明「互不依赖、真正并行」。
- `ArticleAdapter`：作者点击通过 `listener` 回传 Fragment，注释明确「避免把回调耦合进实体」，遵守 `Article` 是 `Serializable`、不可塞回调的约定。
- `ArticleAdapter.handleCategory:111`：`when` 穷举 null/空组合，无嵌套 if。
- `MviViewModel`：单向数据流（Action→State/Event 分离）规范，`viewEvents` 一次性事件与 `viewStates` 分管。

---

## ⚠️ 交叉提醒（重要）

clean-code-reviewer 把 `WebActivity.java` 列为正面范例，是 **Clean Code 视角**（代码清晰、注释讲 WHY），**不代表安全已闭环**。前序安全审查发现的 **#1（exported extra 路径绕过 host 白名单）仍然成立、仍待修**，详见 `docs/2026-06-06-security-review.md`。

---

## 最值得优先处理的 3 件事

1. **全局重命名 `Reporsitory` → `Repository` 并去 `Kt` 后缀**（High，11+ 文件，IDE 一次性安全重构，收益最高）。
2. **统一异常处理**：替换/删除 53 处 `printStackTrace()`，核心链路改 `Logger.e`，协程 catch 放过 `CancellationException`；补 `HomeViewModel.loadMore` 失败回调（High）。
3. **清理死代码 + 合并重复转换**：`FastApplication.kt:175` 不可达 return、`HomeViewModel._text`、`HomeFragment`/`ArticleDetailActivity` 注释死代码；合并 `HomeViewModel` 两份转换为单一 `toArticle()`（Medium+High）。

## 本次实际深读文件清单

1. `home/HomeViewModel.kt`
2. `home/ArticleAdapter.kt`
3. `home/HomeReporsitoryKt.kt`
4. `home/HomeFragment.kt`
5. `article/ArticleDetailActivity.kt`
6. `article/ArticleDetailViewModel.kt`
7. `article/ArticleReporsitoryKt.kt`
8. `app/FastApplication.kt`
9. `demo/floo/WebActivity.java`
10. `demo/mvi/MviViewModel.kt`

抽样/扫描覆盖：`jetpack/flow`（FlowUserViewModel、FlowBasicUsageFragment、FlowDemoFragment）、`demo/recycleview` 命名、跨模块 `printStackTrace`/`Reporsitory`/拼写统计。第三方移植与超大 demo（如 `PrDownloadDemoActivity.java` 1503 行）按范围约定未深读。

> 只读审查，未修改或创建任何代码文件。
