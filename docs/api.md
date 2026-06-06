# 网络 API 文档

> 适用说明：FastAndroid 是技术演示工程，网络层基于 **Retrofit**，没有自建后端。本文记录工程中以 Retrofit 接口声明的「客户端 API 调用面」——即各 `*Service` 接口的方法、HTTP 方法/路径、参数、返回类型与对应的 base URL。
>
> 自定义命令 `/generate-api-docs` 原模板面向 JS/TS REST 项目（JSDoc + curl + TypeScript），已适配为本工程的 Kotlin/Retrofit 形态。
>
> 生成日期：2026-06-06

## 目录

- [Base URL 一览](#base-url-一览)
- [统一响应包装](#统一响应包装)
- [ApiService（libnetwork 核心，多 host）](#apiservicelibnetwork-核心多-host)
- [FlowApiService（MockAPI）](#flowapiservicemockapi)
- [GithubService（GitHub REST v3）](#githubservicegithub-rest-v3)
- [AlbumRetrofitService（last.fm 风格，运行时 base）](#albumretrofitservicelastfm-风格运行时-base)
- [核心数据模型](#核心数据模型)

---

## Base URL 一览

| 用途 | Base URL | 定义位置 |
|------|----------|----------|
| 玩 Android（默认） | `https://www.wanandroid.com` | `ApiConstant.BASE_URL` |
| Flow 演示（MockAPI） | `https://5e510330f2c0d300147c034c.mockapi.io/` | `ApiConstant.FLOW_BASE_URL` |
| GitHub | `https://api.github.com/` | `RetrofitFactory.create(service, baseUrl)` / `CoroutineShowCaseFragment` |
| GitHub 仓库信息（按 Header 动态路由） | `https://api.github.com/repos/%s/%s` | `BaseUrlInterceptor.GITHUB_API_REPO_INFO` |
| 专辑搜索（last.fm 风格） | 运行时通过 `RetrofitFactory.createAlbumService(service, baseUrl)` 注入 | 调用方传入 |

> 说明：`ApiService` 是演示用接口，把不同 host 的端点混在同一个接口里（玩 Android、GitHub、Disney 海报 JSON 等），实际请求 host 取决于调用时使用的 Retrofit 实例与 `Base-Url` Header 路由（见 `BaseUrlInterceptor`）。下文在每个端点标注其归属 host。

---

## 统一响应包装

工程中存在多种返回包装，按端点不同混用：

| 包装类型 | 形态 | 定义/来源 |
|----------|------|-----------|
| `BaseResponse<T>` | `{ data: T, errorCode: Int = -1, errorMsg: String = "" }` | `model/result/BaseResponse.kt` |
| `EmptyResponse` | 空体，仅表示操作成功 | `model/result/EmptyResponse.kt` |
| `NetworkResult<T>` | 自定义 CallAdapter 包装（成功/失败/异常） | `calladapter/networkresult` |
| `ApiResult<T>` | 自定义 CallAdapter 包装 | `calladapter/apiresult` |
| `ApiResponse<T>`（Sandwich） | 三方库 `com.skydoves.sandwich` 的响应包装 | 依赖 |
| `ApiResponse<T>`（自研 LiveData） | `model/result/ApiResponse`，配合 LiveDataCallAdapter | `GithubService` 使用 |

玩 Android 约定：`errorCode == 0` 表示成功，否则 `errorMsg` 为错误信息。

---

## ApiService（libnetwork 核心，多 host）

源码：`libnetwork/src/main/java/com/apache/fastandroid/network/api/ApiService.kt`

| 方法 | HTTP | 路径 | 参数 | 返回 | Host | 备注 |
|------|------|------|------|------|------|------|
| `loadTopArticleCo` | GET | `/article/top/json` | — | `BaseResponse<List<ArticleApi>>` | 玩 Android | 置顶文章（协程） |
| `loadHomeArticleCo` | GET | `/article/list/{pageNum}/json` | `pageNum: Int` | `BaseResponse<HomeArticleResponse>` | 玩 Android | 首页列表（协程） |
| `loadHomeArticleByRxJava` | GET | `/article/list/{pageNum}/json` | `pageNum: Int` | `Observable<BaseResponse<HomeArticleResponse>>` | 玩 Android | 首页列表（RxJava） |
| `collect` | POST | `/lg/collect/{id}/json` | `id: Int` | `Call<BaseResponse<EmptyResponse>>` | 玩 Android | 收藏，需登录；返回 `Call` 故不加 `suspend` |
| `unCollect` | POST | `/lg/uncollect_originId/{id}/json` | `id: Int` | `Call<BaseResponse<EmptyResponse>>` | 玩 Android | 取消收藏 |
| `collect2` | POST | `/lg/collect/{id}/json` | `id: Int` | `BaseResponse<EmptyResponse>` | 玩 Android | 收藏（协程版） |
| `listReposKt` | GET | `/user/{user}/repos` | `user: String` | `List<Repo>` | GitHub 风格 | 协程直接拿列表 |
| `listReposKtWithErrorHandle` | GET | `/user/{user}/repos` | `user: String` | `Response<List<Repo>>` | GitHub 风格 | 带 `Response` 错误处理 |
| `listReposRx` | GET | `/user/{user}/repos` | `user: String` | `Single<List<Repo>>` | GitHub 风格 | RxJava |
| `getArticleById` | GET | `article/get/{id}` | `id: Long` | `ResultData<Repo>` | 玩 Android | — |
| `getArticleByIdWithNetworkResult` | POST | `/lg/collect/{id}/json` | `id: Long` | `NetworkResult<ResultData<Repo>>` | 玩 Android | 演示自定义 `NetworkResult` CallAdapter |
| `fetchDisneyPostersByCoroutine` | GET | `DisneyPosters.json` | — | `ApiResponse<List<Poster>>`（Sandwich） | 静态 JSON | — |
| `fetchDisneyPostersByCall` | GET | `DisneyPosters.json` | — | `Call<List<Poster>>` | 静态 JSON | — |
| `requestRepoInfo` | GET | `GITHUB_API_REPO_INFO` | Header `owner`、`repo` | `ApiResponse<List<Poster>>`（Sandwich） | GitHub | 通过 `Base-Url` Header 路由到 `api.github.com/repos/{owner}/{repo}` |
| `getUsers` | —（无 HTTP 注解） | — | — | `Flow<List<ApiUser>>` | — | 非 Retrofit 端点，接口内的默认方法占位 |

curl 示例（玩 Android 端点）：

```bash
# 置顶文章
curl "https://www.wanandroid.com/article/top/json"

# 首页文章列表第 0 页
curl "https://www.wanandroid.com/article/list/0/json"

# 收藏 id=123 的文章（需登录态 Cookie）
curl -X POST "https://www.wanandroid.com/lg/collect/123/json" \
     -H "Cookie: loginUserName=...; token_pass=..."
```

curl 示例（GitHub 仓库信息，经 Header 路由）：

```bash
curl "https://api.github.com/repos/JerryLiu3502/FastAndroid" \
     -H "Accept: application/vnd.github.v3+json"
```

---

## FlowApiService（MockAPI）

源码：`libnetwork/src/main/java/com/apache/fastandroid/network/api/FlowApiService.kt`
Base URL：`https://5e510330f2c0d300147c034c.mockapi.io/`

| 方法 | HTTP | 路径 | 返回 | 备注 |
|------|------|------|------|------|
| `getUsers` | GET | `users` | `List<ApiUser>` | 协程 |
| `getUsers2` | GET | `users` | `List<ApiUser>` | 同上，演示重复调用 |
| `getMoreUsers` | GET | `more-users` | `List<ApiUser>` | — |
| `getUsersWithError` | GET | `error` | `List<ApiUser>` | 故意触发错误的端点 |
| `getUsersSingle` | GET | `users` | `Single<List<ApiUser>>` | RxJava |

curl 示例：

```bash
curl "https://5e510330f2c0d300147c034c.mockapi.io/users"
curl "https://5e510330f2c0d300147c034c.mockapi.io/more-users"
```

---

## GithubService（GitHub REST v3）

源码：`app/src/main/java/com/android/example/github/api/GithubService.kt`
Base URL：`https://api.github.com/`

| 方法 | HTTP | 路径 | 参数 | 返回 |
|------|------|------|------|------|
| `getUser` | GET | `users/{login}` | `login: String` | `LiveData<ApiResponse<GithubUser>>` |
| `getRepos` | GET | `users/{login}/repos` | `login: String` | `LiveData<ApiResponse<List<Repo>>>` |
| `getRepo` | GET | `repos/{owner}/{name}` | `owner`、`name` | `LiveData<ApiResponse<Repo>>` |
| `getContributors` | GET | `repos/{owner}/{name}/contributors` | `owner`、`name` | `LiveData<ApiResponse<List<Contributor>>>` |
| `searchRepos` | GET | `search/repositories` | Query `q` | `LiveData<ApiResponse<RepoSearchResponse>>` |
| `searchRepos`（重载） | GET | `search/repositories` | Query `q`、`page` | `Call<RepoSearchResponse>` |

curl 示例：

```bash
curl "https://api.github.com/users/JerryLiu3502"
curl "https://api.github.com/repos/JerryLiu3502/FastAndroid/contributors"
curl "https://api.github.com/search/repositories?q=android&page=1"
```

---

## AlbumRetrofitService（last.fm 风格，运行时 base）

源码：`app/src/main/java/com/apache/fastandroid/demo/showcase/data/datasource/api/service/AlbumRetrofitService.kt`
Base URL：运行时由 `RetrofitFactory.createAlbumService(service, baseUrl)` 注入（last.fm 风格 `method=` 查询接口）。

| 方法 | HTTP | 路径 | 参数 | 返回 |
|------|------|------|------|------|
| `searchAlbumAsync` | POST | `./?method=album.search` | Query `album`（默认 `DEFAULT_QUERY_NAME`）、`limit`（默认 60） | `ApiResult<SearchAlbumResponse>` |
| `getAlbumInfoAsync` | POST | `./?method=album.getInfo` | Query `artist`、`album`、`mbid?` | `ApiResult<GetAlbumInfoResponse>` |

> base URL 在源码中未硬编码为常量，需查看实例化 `createAlbumService` 的调用方确认实际域名，故此处不提供 curl 示例。

---

## 核心数据模型

`BaseResponse<T>`（`model/result/BaseResponse.kt`）

```kotlin
open class BaseResponse<T>(
    var data: T,
    var errorCode: Int = -1,
    var errorMsg: String = "",
)
```

`HomeArticleResponse`（`model/HomeArticleResponse.kt`）

```kotlin
data class HomeArticleResponse(
    var curPage: Int,
    var datas: List<ArticleApi>,
    var offset: Int,
    var over: Boolean,
    var pageCount: Int,
    var size: Int,
    var total: Int,
)
```

`ArticleApi`（`model/ArticleApi.kt`）——服务器返回的文章实体

```kotlin
data class ArticleApi(
    var primaryKeyId: Int = 0,
    var id: Int = 0,
    var author: String = "",
    var shareUser: String = "",
    var chapterName: String? = "",
    var desc: String = "",
    var link: String = "",
    var originId: Int = 0,
    var title: String = "",
    var collect: Boolean = false,
    var superChapterName: String? = "",
    var niceDate: String = "",
    var fresh: Boolean = false,
    var top: Boolean = false,
    var envelopePic: String = "",
)
```

> 其余模型（`Repo`、`Poster`、`ApiUser`、`GithubUser`、`Contributor`、`RepoSearchResponse`、`SearchAlbumResponse`、`GetAlbumInfoResponse`、`ResultData` 等）字段详见各自源码文件。
