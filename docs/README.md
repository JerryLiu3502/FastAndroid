# 文档索引

FastAndroid 项目文档目录。返回 [项目根 README](../README.md)。

## 目录

| 文档 | 分类 | 内容 |
|------|------|------|
| [overview-design.md](overview-design.md) | 架构 | 概要设计——总体架构、模块职责、应用启动流程、首页 Feed 数据流、网络层、性能监控、构建工程化、扩展规范 |
| [api.md](api.md) | 接口参考 | 网络 API——各 Retrofit 接口（`ApiService` / `FlowApiService` / `GithubService` / `AlbumRetrofitService`）的端点、参数、响应包装与 base URL，含 curl 示例 |
| [AI_LOOP.md](AI_LOOP.md) | 工具 | AI 自动优化循环：跑 check 命令 → 喂失败日志给 AI 修复 → 再校验 → 通过则自动 commit/push |

## 相关约定（位于仓库根目录）

- [AGENTS.md](../AGENTS.md)：项目级协作规范（提交、分支与推送、测试放置、安全）。
- [CLAUDE.md](../CLAUDE.md)：面向 Claude Code 的项目指引（项目性质、常用命令、架构与编码约定）。

## 文档维护约定

- 新增项目文档统一放在 `docs/`，不写入全局配置目录。
- 适合写文档的场景：架构设计、接口约定、跨模块方案、重要设计决策、交接说明。
- 简单 Bug 修复、文案/样式微调不强制写文档。
- 不要把密钥、token 等敏感信息写入 `docs/`。
