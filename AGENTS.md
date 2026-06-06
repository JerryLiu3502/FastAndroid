# Repository Guidelines

## Project Structure & Module Organization

This is a multi-module Android Gradle project. The main application lives in `app/`; shared UI and base utilities are in `baselib/`; reusable framework code is in `fastFramework/`; networking, API models, interceptors, and call adapters are in `libnetwork/`. Each module follows the standard Android layout: `src/main/java` for Kotlin/Java, `src/main/res` for resources, `src/main/assets` for bundled assets, and `src/test` or `src/androidTest` for tests. Shared Gradle configuration is kept at the root in files such as `version.gradle`, `version_config.gradle`, `base_lib.gradle`, and `playFlavor.gradle`.

## Build, Test, and Development Commands

- `./gradlew assembleFreeDebug` builds the debug APK for the `free` flavor.
- `./gradlew assembleProdRelease` builds the minified release APK for the `prod` flavor.
- `./gradlew testFreeDebugUnitTest` runs local JVM unit tests for the app debug variant.
- `./gradlew connectedFreeDebugAndroidTest` runs instrumentation tests on a connected device or emulator.
- `./gradlew clean` removes Gradle build output and archived APK output.
- `./gradlew archiveOutApks` copies generated APKs into `outapk/archives`.

Use Android Studio or a local `local.properties` file with `sdk.dir` configured before building.

## Coding Style & Naming Conventions

Use Kotlin and Java conventions already present in the codebase: classes in `PascalCase`, methods and properties in `camelCase`, constants in `UPPER_SNAKE_CASE`, and Android resources in `lower_snake_case`. Keep package paths under the module’s existing namespace, especially `com.apache.fastandroid`. Import the IntelliJ/Android Studio code style from `config/fast_android_style.xml` when possible. Library modules inherit Java 8 and Kotlin JVM target settings from `base_lib.gradle`.

## Testing Guidelines

Place JVM tests in `src/test/java` and instrumentation tests in `src/androidTest/java`. Name test classes after the behavior or component under test, for example `BasicActivityTests`. Use JUnit for local tests and AndroidX test runner/rules for device tests. Add or update tests for network behavior, lifecycle-sensitive code, and UI flows when changing related modules.

## Commit & Pull Request Guidelines

Recent history uses short messages, often with a `feat:` prefix and a brief area summary, for example `feat: demo 1.添加一些 demo`. Prefer concise imperative commits such as `feat: add coroutine demo` or `fix: handle token refresh retry`. Pull requests should describe the change, list tested Gradle commands, link related issues, and include screenshots or screen recordings for visible UI changes.

### 分支与推送约定

- **默认在当前所在分支上工作，不自动新建或切换分支。** 分支由用户自行切换；只有当用户明确要求「新开分支」或「切到某分支」时，才创建或切换分支。新建时命名 `<type>/<简述>`，例如 `feat/home-feed-cache`、`fix/agentweb-dep`。
- 提交遵循上面的 conventional commits 约定，按逻辑拆分。
- **push 到远端前必须取得用户明确授权**，无论在哪个分支；禁止对公共分支强推或重写历史。
- 是否走 PR 由用户决定；需要开 PR 时用 `gh pr create`，正文说明「改了什么 / 为什么 / 如何验证 / 影响范围」。

## Security & Configuration Tips

Do not commit new secrets, keystores, or local SDK paths. Treat files under `sign/` and generated APK archives as sensitive. Keep environment-specific values in Gradle properties or local configuration, not hard-coded in source.
