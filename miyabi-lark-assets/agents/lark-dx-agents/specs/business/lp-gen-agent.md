# LPGenAgent仕様書

## エージェント概要

**名称**: LPGenAgent（Landing Page Generation Agent）
**カテゴリ**: Business Agent
**優先度**: P2-High
**キャラクター名**: つくるんLP（LP作成専門スタッフ）

## 目的

参考URLを入力するだけで、そのデザイン・構造を自動分析し、ユーザーのコンテンツに合わせた高品質なランディングページを自動生成する。

## コアコンピテンシー

### 主要機能

1. **参考サイト自動分析**
   - WebFetchによるデザイン解析
   - レイアウト構造の抽出
   - 色彩体系の識別
   - セクション構成の把握
   - レスポンシブ対応の確認

2. **インタラクティブ情報収集**
   - サービス名・製品名
   - ターゲット顧客
   - 主要訴求ポイント（3つ）
   - キャッチコピー
   - アクセントカラー選択
   - CTA内容（複数可）

3. **HTML自動生成**
   - TailwindCSS v3.4使用
   - レスポンシブデザイン（Mobile-First）
   - アクセシビリティ対応（ARIA属性）
   - SEO最適化（meta tags）
   - パフォーマンス最適化

4. **コンテンツ構成**
   - ファーストビュー（ヒーロー）
   - 課題提示セクション
   - ソリューション提示
   - 特徴・メリット（3つ）
   - 料金プラン
   - ユーザーの声（テストモニアル）
   - FAQ
   - CTA（複数配置）
   - フッター

## 入力仕様

### 必須入力

```typescript
interface LPGenInput {
  referenceUrl: string;              // 参考サイトURL
  serviceName: string;                // サービス名
  targetAudience: string;             // ターゲット顧客
  mainCatchphrase: string;            // メインキャッチコピー
  valuePropositions: string[];        // 主要価値提案（3つ）
  accentColor: 'blue' | 'green' | 'purple' | 'orange';
  ctaTypes: ('trial' | 'download' | 'contact' | 'demo')[];
}
```

### オプション入力

```typescript
interface LPGenOptionalInput {
  companyName?: string;               // 会社名
  logo?: string;                      // ロゴURL
  heroImage?: string;                 // ヒーロー画像URL
  testimonials?: Testimonial[];       // 顧客の声
  pricingPlans?: PricingPlan[];      // 料金プラン
  faqItems?: FAQItem[];              // FAQ項目
}
```

## 出力仕様

### 生成ファイル

1. **`index.html`** - メインHTMLファイル
   - 完全なセマンティックHTML5
   - TailwindCSS v3.4 CDN統合
   - Google Fonts統合
   - Open Graph tags
   - Twitter Card tags
   - Favicon参照

2. **`README.md`** - 使用方法ドキュメント
   - カスタマイズ方法
   - カラー変更手順
   - 画像差し替え手順
   - デプロイ手順

3. **`design-analysis.json`** - デザイン分析結果
   - 参考サイトの構造情報
   - 色彩体系
   - レイアウトパターン
   - 使用フォント

## 実行フロー

### Step 1: 参考サイト分析

```
INPUT: referenceUrl
↓
WebFetch実行
↓
OUTPUT: デザイン分析結果
- レイアウト構造
- 色彩体系
- セクション構成
- レスポンシブ対応
```

### Step 2: 情報収集

```
AskUserQuestion実行（4問）
1. サービス種別（4択）
2. アクセントカラー（4択）
3. CTA種別（複数選択可）
4. ターゲット顧客（記述式）
```

### Step 3: コンテンツ生成

```
情報統合
↓
HTMLテンプレート生成
- ヘッダー
- ヒーローセクション
- 特徴セクション（3つ）
- ソリューションセクション
- 料金セクション
- テストモニアルセクション
- FAQセクション
- CTAセクション（複数）
- フッター
```

### Step 4: 出力

```
ファイル生成
- index.html
- README.md
- design-analysis.json
↓
プレビューURL表示
デプロイ手順案内
```

## 技術スタック

### フロントエンド

- **HTML5** - セマンティックマークアップ
- **TailwindCSS v3.4** - ユーティリティファーストCSS
- **Alpine.js v3** - 軽量JavaScriptフレームワーク（インタラクティブ要素）
- **Google Fonts** - タイポグラフィ

### 依存関係

- **WebFetch Tool** - 参考サイト分析
- **AskUserQuestion Tool** - 情報収集
- **Write Tool** - ファイル生成

## デザインパターン

### カラーパレット

```typescript
const colorSchemes = {
  blue: {
    primary: '#2563eb',      // 信頼・安定
    secondary: '#3b82f6',
    accent: '#60a5fa',
    text: '#1e3a8a'
  },
  green: {
    primary: '#10b981',      // 成長・安心
    secondary: '#34d399',
    accent: '#6ee7b7',
    text: '#065f46'
  },
  purple: {
    primary: '#8b5cf6',      // 革新・創造
    secondary: '#a78bfa',
    accent: '#c4b5fd',
    text: '#5b21b6'
  },
  orange: {
    primary: '#f97316',      // 活力・情熱
    secondary: '#fb923c',
    accent: '#fdba74',
    text: '#9a3412'
  }
};
```

### レイアウトパターン

1. **Z型パターン** - 視線の流れを考慮
2. **F型パターン** - テキストコンテンツ中心
3. **グリッドレイアウト** - 特徴・メリット表示
4. **フルワイドセクション** - ヒーロー・CTA

### レスポンシブブレークポイント

```css
sm: 640px   /* Mobile Large */
md: 768px   /* Tablet */
lg: 1024px  /* Desktop */
xl: 1280px  /* Desktop Large */
2xl: 1536px /* Desktop XL */
```

## 品質基準

### パフォーマンス

- ✅ Lighthouse Performance Score: 90+
- ✅ First Contentful Paint (FCP): < 1.5s
- ✅ Largest Contentful Paint (LCP): < 2.5s
- ✅ Cumulative Layout Shift (CLS): < 0.1

### アクセシビリティ

- ✅ WCAG 2.1 Level AA準拠
- ✅ キーボードナビゲーション対応
- ✅ スクリーンリーダー対応
- ✅ カラーコントラスト比 4.5:1以上

### SEO

- ✅ セマンティックHTML使用
- ✅ meta description（155文字以内）
- ✅ Open Graph tags完備
- ✅ 構造化データ（JSON-LD）

## エラーハンドリング

### エラーケース

1. **参考URL取得失敗**
   - リトライ（最大3回）
   - デフォルトデザインパターン使用

2. **ユーザー入力不足**
   - 再質問
   - デフォルト値提案

3. **ファイル生成失敗**
   - エラーログ出力
   - 部分的な出力提供

## エスカレーション条件

以下の場合、CoordinatorAgentにエスカレーション：

1. **複雑なインタラクション要件**
   - カスタムJavaScript実装が必要
   - バックエンド連携が必要
   - 決済システム統合

2. **大規模カスタマイズ**
   - 10セクション以上の構成
   - 複雑なアニメーション要件
   - 独自フレームワーク使用

3. **技術的制約**
   - 参考サイトが特殊技術使用
   - レガシーブラウザ対応要件
   - 複雑なレスポンシブ要件

## 使用例

### 基本的な使用方法

```bash
# Miyabi CLIから実行
miyabi agent run lp-gen --reference-url "https://example.com"

# 対話形式で情報入力
# ↓
# HTML生成
# ↓
# プレビュー
```

### Claude Code統合

```bash
# .claude/commands/generate-lp.md を使用
/generate-lp https://happytry-lp.site?vos=meta
```

## メンテナンス

### 定期更新項目

- ✅ TailwindCSS バージョン（四半期ごと）
- ✅ デザイントレンド反映（半期ごと）
- ✅ アクセシビリティ基準（年次）

### モニタリング指標

- 生成成功率: 95%以上
- ユーザー満足度: 4.5/5.0以上
- 平均生成時間: 3分以内

## 関連ドキュメント

- **実行プロンプト**: `.claude/agents/prompts/business/lp-gen-agent-prompt.md`
- **使用例**: `.claude/agents/examples/lp-gen-examples.md`
- **キャラクター図鑑**: `.claude/agents/AGENT_CHARACTERS.md`

---

**バージョン**: v1.0.0
**ステータス**: 📋 Planning (実装予定)
**Target Release**: v1.3.0
**最終更新**: 2025-10-22
**ステータス**: Active
