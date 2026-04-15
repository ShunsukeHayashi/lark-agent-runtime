# 参与 LARC

[English](CONTRIBUTING.md) | 简体中文 | [日本語](CONTRIBUTING.ja.md)

---

## 适用范围

LARC 仍然处于 incubation 阶段。

目前最适合社区参与的区域是：

- 文档改进
- 与真实 `lark-cli` 行为对齐的命令修正
- permission model 的清晰化
- `auth suggest` 回归案例补充
- 非破坏性的验证辅助脚本

---

## 开始前建议阅读

- [README.md](README.md)
- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)

如果你的改动会影响 permission logic，也请阅读：

- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)

---

## 适合优先贡献的方向

### 1. 文档

- 补充术语解释
- 增加示例
- 修正英文、中文、日文文档之间的语义偏差

### 2. 命令对齐

- 验证 shell wrapper 是否与真实 `lark-cli` 一致
- 改善命令形状错误时的报错提示

### 3. Permission intelligence

- 增加真实办公任务样例
- 减少过宽的 scope 推断
- 改进 authority explanation

### 4. 验证工具

- 扩展回归检查
- 增加非破坏性的 smoke test

---

## 边界

请不要提交以下类型的改动：

- 暴露 tenant 级别的密钥、ID 或凭据
- 把 private 内部资产当作 public API
- 默认引入破坏性自动化
- 让项目偏离 Lark-native office-work agents 这个核心方向

较大的架构改动，建议先从 issue 或设计说明开始。

---

## 三语言文档策略

项目正朝着三语言公开文档体系推进。

- 英文是公共技术文档的 canonical authoring language
- 简体中文是面向主市场的公开镜像
- 日文是持续维护的镜像与策略桥接文档

请保持三种语言的语义一致，不要形成互相冲突的三套定义。

---

## Pull Request 建议

尽量保持 PR 小而聚焦。

好的 PR 通常会说明：

- 问题是什么
- 对应哪个 playbook 或设计文档
- 对使用者有什么影响
- 做了哪些验证

如果没有跑测试，请明确写出来。

---

## 建议流程

1. 先明确 issue 或目标区域
2. 保持改动小而清晰
3. 验证相关命令或文档路径
4. 如果行为变化了，也更新 docs
5. 在 PR 中写清剩余风险和限制

---

## 验证建议

在提交 PR 之前，至少建议先运行下面两项轻量检查：

```bash
# 检查入口脚本与辅助脚本的 shell 语法
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh

# 检查 permission-intelligence 回归用例
bash scripts/auth-suggest-check.sh --verify
```

如果没有运行测试，也请在 PR 里明确说明原因。

---

## 当前高价值空白区

- 提升 `auth suggest` 的最小权限精度
- 强化 approval model
- 提升基于 Lark Drive 的 disclosure-chain realism
- 推进面向中国市场的 OSS 发布准备
