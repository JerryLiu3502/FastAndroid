---
  name: security-review
  description: 审查代码的安全问题（注入、鉴权、密钥泄露）。当
  用户提到安全审查、漏洞、security
  review、检查代码安全时自动使用。
  allowed-tools: Read, Grep, Glob
  ---

  # 安全审查

  分析代码，重点检查：
  1. SQL/命令注入风险
  2. 鉴权与越权问题
  3. 硬编码的密钥/token
  4. 输入校验缺失

  按「问题 / 位置 / 影响 / 修复建议」格式输出。