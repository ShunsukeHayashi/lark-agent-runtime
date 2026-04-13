# LARC 用語集

[English](terminology-glossary.md) | [简体中文](terminology-glossary.zh-CN.md) | 日本語

---

## 目的

この用語集は、LARC の重要語彙を英語・中国語・日本語で揃えるためのものです。

対象:

- README と公開ドキュメント
- permission / approval 関連ドキュメント
- issue template や contribution docs
- 将来の三言語公開資料

---

## 主要用語

| English | Chinese | Japanese | 意味 |
|---|---|---|---|
| Lark Agent Runtime | Lark Agent Runtime | Lark Agent Runtime | このプロジェクトの正式名称 |
| LARC | LARC | LARC | Lark Agent Runtime の略称 |
| Lark-native | 飞书原生 | Lark ネイティブ | Lark を単なる API 接続先ではなく、実際の実行面として扱う考え方 |
| disclosure chain | 披露链 | ディスクロージャーチェーン | `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` のような順序付きコンテキスト列 |
| permission-first | 权限优先 | 権限先行 | 実行前に scope と authority を説明する設計思想 |
| scope | scope / 权限范围 | スコープ | 機能を実行するために必要な API 権限単位 |
| authority | 执行身份 / authority | 実行権限主体 | どの主体としてアクションを実行するか |
| user authority | 用户身份执行 | ユーザー権限主体 | `user_access_token` などで実在ユーザーとして実行する形 |
| bot authority | 机器人身份执行 | Bot 権限主体 | `tenant_access_token` などで Bot / app として実行する形 |
| mixed authority | 混合执行身份 | 混合権限主体 | 複数の authority type をまたぐワークフロー |
| permission intelligence | 权限智能 | Permission intelligence | 権限推論・説明・検証を担う LARC の中核部分 |
| minimum likely scopes | 最小可能权限集 | 最小想定スコープ | あるタスクに対して現実的に最小と考えられる scope 集合 |
| execution gate | 执行门控 | 実行ゲート | アクションを進めるか止めるかを決める制御点 |
| approval gate | 审批门控 | 承認ゲート | Lark Approval を実行制御として使う考え方 |
| memory surface | 记忆表面 | 記憶面 | Base など、エージェント記憶を置く表面 |
| operating surface | 运行表面 | 実行面 | エージェントが実際に動作するネイティブな表面 |

---

## 使い分け

- 誰の権限として動くかを話すときは `authority` を優先
- API 権限単位を話すときは `scope` を優先
- このプロジェクトの立場を示すときは `Lark-native` を優先
- 順序付きコンテキスト読込を話すときは `disclosure chain` を優先

---

## 翻訳ルール

どれかの言語で語義がぶれ始めたら、README や設計書を増やす前に、まずこの用語集を更新します。
