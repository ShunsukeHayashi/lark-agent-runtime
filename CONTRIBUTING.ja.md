# LARC へのコントリビュート

[English](CONTRIBUTING.md) | [简体中文](CONTRIBUTING.zh-CN.md) | 日本語

---

## 対象範囲

LARC はまだ incubation 段階のプロジェクトです。

現時点で特に歓迎しやすいのは次の領域です。

- ドキュメント改善
- 実際の `lark-cli` 挙動に合わせた command alignment 修正
- permission model の明確化
- `auth suggest` の回帰ケース追加
- 破壊的でない検証補助スクリプト

---

## 作業前に読むもの

- [README.md](README.md)
- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)

permission logic に触る場合は、こちらも見てください。

- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)

---

## 着手しやすい領域

### 1. ドキュメント

- 用語の説明改善
- 例の追加
- 英語・中国語・日本語の意味ズレ修正

### 2. コマンド整合

- shell wrapper が実際の `lark-cli` と一致しているかの確認
- コマンド形状が違うときのエラーメッセージ改善

### 3. Permission intelligence

- 現実的なオフィスタスク例の追加
- 過剰 scope 推論の削減
- authority explanation の改善

### 4. 検証補助

- 回帰確認の拡張
- 非破壊の smoke test 追加

---

## 境界条件

次のような変更は避けてください。

- tenant 固有の秘密情報や ID、credential を含む変更
- private な内部資産を public API のように扱う変更
- 破壊的な自動化をデフォルトにする変更
- このプロジェクトの軸を Lark-native office-work agents 以外へずらす変更

大きな設計変更は、まず issue や設計メモから始めるのが安全です。

---

## 三言語ドキュメント方針

公開ドキュメントは三言語化を前提に整備しています。

- 英語は public technical docs の canonical authoring language
- 簡体字中国語は主市場向けミラー
- 日本語は maintained mirror と戦略整理の橋渡し

3言語で意味が競合しないようにしてください。

---

## PR の考え方

PR は小さく、焦点を絞るのが理想です。

良い PR は通常、次を含みます。

- 何が問題か
- どの playbook / design doc に紐づくか
- 利用者にどう影響するか
- 何を検証したか

テスト未実施なら、その旨を明記してください。

---

## 推奨フロー

1. まず issue か対象領域を明確にする
2. 変更は小さく保つ
3. 関連コマンドや文書を確認する
4. 挙動変更があれば docs も更新する
5. 残るリスクや制約を PR に書く

---

## 検証の目安

PR 前の軽量な確認として、少なくとも次を推奨します。

```bash
# エントリポイントと補助スクリプトの構文確認
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh

# permission-intelligence の回帰確認
bash scripts/auth-suggest-check.sh --verify
```

テスト未実施なら、その理由も PR に書いてください。

---

## 価値の高い未解決領域

- `auth suggest` の最小権限精度向上
- approval model の強化
- Lark Drive 上での disclosure-chain realism の改善
- 中国向け OSS 公開準備の整備
