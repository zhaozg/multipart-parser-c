# AGENTS.md

multipart.c 是基于 multipart-parser-c 实现的 multipart/form-data 的 Lua 绑定解析库。
multipart.lua 是对 multipart.c 的封装，提供更易用的 Lua 接口, 具有两个功能:

1. HTTP multipart POST parse
1. HTTP multipart POST build

本文档为 AI 开发者提供开发约束、任务指导。

## 1. 概述

- Agent 角色：本项目未直接实现智能体 但所有解析、测试、优化、文档等任务
均可通过智能体化（如 AI 代码助手）辅助完成。
- 核心目标：高性能、易于扩展、测试与使用。

## 2. 主要接口与职责

按照 `multipart.c` 导出的 Lua API, 进行处理.

## 3. 开发任务

- 在 multipart.lua 中实现 parse, build 两个 Lua 函数。
- 参考 test-multipart.lua 中的测试用例，形成 parse, build 两个函数。
- 可以使用 lpeg 进行辅助解析。
- 完全符合规范，支持文件上传、字段解析等常见场景, 可修复测试用例中自身的错误。
- 在 multipart.lua 中使用 LDoc 进行文档注释。

## 4. 开发指南

- 考虑 Lua 5.x 兼容性, 必需支持 LuaJIT v2.1
- 测试驱动开发：所有功能需配套测试。

## 5. 贡献与协作流程

1. Fork 仓库，创建 feature 分支。
2. 开发/优化/补充文档，确保所有测试通过（`make test`）。
3. 补充/更新相关文档与注释。
4. 提交 Pull Request，描述变更点与优化点。
5. 由维护者 review 并合并。

## 6. 文档与代码规范

- 代码注释采用英文，关键逻辑建议详细说明。
- 文档结构清晰，分章节、分任务类型描述。
- 注意源代码中避免空行(仅空格或字表符).
- 参考现有 `README.md` 目录文档风格。

## 7. Agent 能力建议

- 能自动分析程序逻辑，定位问题。
- 能自动生成/补全测试用例。
- 能自动补全 API 注释与用例文档。
- 能根据性能报告自动提出优化建议。

## 8. 参考资料

- RFC 7578 (2015): "Returning Values from Forms: multipart/form-data"
- RFC 2046 (1996): "Multipurpose Internet Mail Extensions (MIME) Part Two: Media Types"
- Dependent RFC specifications
- 本项目 `README.md`、`doc/*.md`

---

如需智能体协助开发、优化、文档任务，请参考本指南，结合现有代码与文档规范进行。
