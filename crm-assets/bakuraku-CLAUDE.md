# CLAUDE.md — bakuraku

**言語**: 日本語。コード・コミットメッセージは英語。

## プロジェクト概要

バクラク（LayerX）を使わずに、**Lark（飛書）だけでバクラク相当のバックオフィス機能を実現する**プロジェクト。

詳細仕様: `SPEC.md` を参照。

## 開発方針

- **Lark ファースト**: できる限り Lark ネイティブ機能（Base・承認・Bot）で実現する
- CLIツールは Lark 単体で完結できない操作のみを補助する
- 通知はすべて Flex Message でリッチに表示する

## 技術スタック

- TypeScript (strict mode, ESM)
- pnpm
- lark-cli（Lark API ラッパー）
- commander.js（CLI フレームワーク）

## コマンド

```bash
pnpm install     # 依存関係インストール
pnpm dev         # 開発モード
pnpm build       # ビルド
pnpm test        # テスト
```

## ディレクトリ構成（予定）

```
bakuraku/
├── CLAUDE.md
├── SPEC.md
├── package.json
├── src/
│   ├── cli/         # CLIコマンド定義
│   ├── lark/        # Lark API クライアント
│   ├── features/    # 機能別ロジック
│   │   ├── expense/ # 経費精算
│   │   ├── invoice/ # 請求書
│   │   └── report/  # レポート
│   └── index.ts
└── tests/
```

## 実装優先順位

1. Phase 1: 経費精算（Lark Base + 承認 + Bot通知）
2. Phase 2: 稟議・申請
3. Phase 3: 請求書管理
4. Phase 4: CLIツール
5. Phase 5: 分析・レポート
