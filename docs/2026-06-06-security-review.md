# 安全审查记录（2026-06-06）

| 项 | 内容 |
|----|------|
| 日期 | 2026-06-06 |
| 范围 | FastAndroid 仓库整体 + 本会话改动文件 |
| 重点 | SQL/命令注入、鉴权/越权、硬编码密钥、输入校验 |
| 性质 | 演示工程，影响整体收敛；本记录用于跟踪发现与处置 |

> 演示工程定位，下列问题“影响”均指模式本身的风险；实际暴露面被学习场景收敛。

## 已修复

### #1 exported WebView 加载任意外部 URL（中危）
- 位置：`app/.../demo/floo/WebActivity.java` + `AndroidManifest.xml:216-230`
- 根因：Activity `exported="true"` + `BROWSABLE` deeplink，`url` 取自 intent/deeplink 后仅判 null 即 `setJavaScriptEnabled(true)` + `loadUrl`；`shouldOverrideUrlLoading` 无条件放行任意跳转；且 `url==null` 未 `return` 存在 `loadUrl(null)` NPE。
- 处置（已改，最小改动，保持 Java）：
  - 新增 scheme 白名单（仅 `http`/`https`），挡 `javascript:`/`file:`/`content:`/`intent:` 等注入与本地文件读取；
  - 来源分级：内部 `getStringExtra` 放宽、外部 deeplink `getData` 可叠加 host 白名单（`ALLOWED_HOSTS`，默认空=仅按 scheme 限制）；
  - `shouldOverrideUrlLoading` 非白名单 scheme 交系统处理，不在应用内 WebView 加载；
  - 修复 `url==null` 未 `return` 的崩溃隐患。
- 后续可选增强：若要严格收紧，在 `ALLOWED_HOSTS` 填入可信域名即可。

### #4 假 token 注释澄清（低危/误报）
- 位置：`app/.../demo/rxjava/RxJava3PracticeFragment.kt:363`
- 处置：补注释标明为演示“刷新 token”流程的占位假值，非真实凭证，避免后续被误判为硬编码密钥。

## 待办（按需修，勿借机重构）

### #2 老式 SQLite Helper 字符串拼接 SQL（中低危，当前不可注入）
- 位置：`app/src/main/java/com/downloader/database/AppDbHelper.java:46/121/135`、`DatabaseOpenHelper.java:39`
- 现状：拼接的是 `int`/`long`（强类型，当前不可注入），表名/列名为常量。
- 风险：反模式——一旦参数改为 `String`（如按 fileName/url 查询）即产生注入。
- 建议：统一改参数化（`rawQuery("... WHERE id = ?", new String[]{...})`、`execSQL` 用占位符）；`insert/update` 已用 `ContentValues`+`?`，保持。
- 备注：属第三方下载库 `com.downloader` 代码，遵循“现有代码不主动迁移/大改”，按需处理。

### #3 全局允许明文 HTTP 流量（中低危）
- 位置：`AndroidManifest.xml:26` `usesCleartextTraffic="true"` + `res/xml/network_security_config.xml` `cleartextTrafficPermitted="true"`；实际明文调用见 `demo/weaknetwork/*`、`todoapp/ViewModelFactory.kt:162`。
- 风险：明文传输可被中间人窃听/篡改。
- 建议：`network_security_config` 改为按 host 白名单只对确需明文的域名放行，而非全局 `true`；能换 `https` 的 demo 尽量换。

## 复核结论
- 无真实硬编码密钥泄露；签名口令从 `prod.properties`（gitignore）读取，正确。
- 无当前可利用的 SQL 注入。
- 本会话改动的 `ArticleAdapter.kt`/`HomeViewModel.kt`/`Article.kt`/`Libs.kt` 未引入安全问题；`displayTitle` 经 `CommonUtil.fromHtml` 后用 TextView（非 WebView）展示，无 XSS。
