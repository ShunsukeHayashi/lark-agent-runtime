# LPGenAgent使用例集

## 目次

1. [基本的な使用例](#基本的な使用例)
2. [業種別事例](#業種別事例)
3. [カラーパターン別事例](#カラーパターン別事例)
4. [CTA種別別事例](#CTA種別別事例)
5. [カスタマイズ事例](#カスタマイズ事例)

---

## 基本的な使用例

### 例1: SaaSサービスのLP生成

**参考URL**: https://stripe.com/

**コマンド**:
```bash
/generate-lp https://stripe.com/
```

**質問への回答**:
```
1. サービス種別: SaaS/Webサービス
2. アクセントカラー: 紫系（革新・創造）
3. CTA種別: 無料トライアル、資料ダウンロード
4. 基本情報:
   - サービス名: PayFlow
   - ターゲット: 中小企業の経営者、EC事業者
   - キャッチコピー: 決済をシンプルに、ビジネスを加速する
   - 価値提案:
     1. 主要決済手段を一括統合
     2. 導入30分、即日利用開始
     3. 業界最安値の手数料2.9%
```

**生成結果**:
```
✅ ランディングページ生成完了！

📁 生成ファイル:
- index.html (16KB)
- design-analysis.json (2.1KB)
- README.md (3.2KB)

🎨 デザイン情報:
- プライマリカラー: #8b5cf6（紫系）
- セクション数: 9個
- CTA数: 3箇所

📋 生成されたセクション:
1. ヘッダー（ナビゲーション + CTA）
2. ヒーローセクション（キャッチコピー + 2つのCTA）
3. 特徴セクション（3つの価値提案）
4. ソリューションセクション（課題→解決策）
5. 料金プラン（3つのプラン）
6. テストモニアル（顧客の声）
7. FAQセクション（5つの質問）
8. 最終CTAセクション
9. フッター

🚀 デプロイ: vercel deploy
```

---

## 業種別事例

### 例2: コンサルティングサービス

**参考URL**: https://www.mckinsey.com/

**質問への回答**:
```
1. サービス種別: コンサルティング
2. アクセントカラー: 青系（信頼・安定）
3. CTA種別: 問い合わせ、デモ予約
4. 基本情報:
   - サービス名: BizConsult Pro
   - ターゲット: 中堅企業の経営層、事業責任者
   - キャッチコピー: データドリブンで経営を変革する
   - 価値提案:
     1. 20年の実績、500社以上の支援
     2. 業界特化型のコンサルタント
     3. 成果報酬型で低リスク
```

**特徴**:
- 信頼性重視の青系カラー
- 実績・事例を強調
- 問い合わせフォーム最適化

---

### 例3: ECサイト

**参考URL**: https://www.warbyparker.com/

**質問への回答**:
```
1. サービス種別: ECサイト
2. アクセントカラー: オレンジ系（活力・情熱）
3. CTA種別: 無料トライアル（商品サンプル）、資料ダウンロード（カタログ）
4. 基本情報:
   - サービス名: EcoWear
   - ターゲット: 環境意識の高い20-40代
   - キャッチコピー: サステナブルなファッションで、地球に優しく
   - 価値提案:
     1. 100%オーガニックコットン使用
     2. 売上の1%を環境保護活動に寄付
     3. カーボンニュートラル配送
```

**特徴**:
- 商品画像を大きく配置
- サステナビリティを強調
- ビジュアル重視のレイアウト

---

## カラーパターン別事例

### 例4: 青系（信頼・安定）

**最適業種**: 金融、保険、医療、法律、BtoB SaaS

**生成例**:
```
サービス名: SecureBank
カラー: #2563eb（青）
印象: 信頼できる、安全、プロフェッショナル
使用シーン: 金融機関、セキュリティサービス
```

**HTML抜粋**:
```html
<!-- ヒーローセクション -->
<section class="bg-gradient-to-br from-blue-50 to-white">
  <button class="bg-blue-600 text-white hover:bg-blue-700">
    無料相談を予約
  </button>
</section>

<!-- 特徴セクション -->
<div class="bg-blue-600 text-white">
  <svg class="w-8 h-8 text-blue-100"><!-- アイコン --></svg>
</div>
```

---

### 例5: 緑系（成長・安心）

**最適業種**: 環境、健康、教育、農業、フィンテック

**生成例**:
```
サービス名: GreenHealth
カラー: #10b981（緑）
印象: 安心、成長、自然、健康
使用シーン: 健康食品、エコサービス
```

**HTML抜粋**:
```html
<section class="bg-gradient-to-br from-green-50 to-white">
  <button class="bg-green-500 text-white hover:bg-green-600">
    今すぐ始める
  </button>
</section>
```

---

### 例6: 紫系（革新・創造）

**最適業種**: AI/ML、デザイン、クリエイティブ、スタートアップ

**生成例**:
```
サービス名: AIStudio
カラー: #8b5cf6（紫）
印象: 革新的、創造的、ユニーク、未来的
使用シーン: AI サービス、クリエイティブツール
```

**HTML抜粋**:
```html
<section class="bg-gradient-to-br from-purple-50 to-white">
  <button class="bg-purple-600 text-white hover:bg-purple-700">
    AIを体験する
  </button>
</section>
```

---

### 例7: オレンジ系（活力・情熱）

**最適業種**: スポーツ、エンタメ、教育、飲食、旅行

**生成例**:
```
サービス名: FitLife
カラー: #f97316（オレンジ）
印象: 活力的、情熱的、エネルギッシュ、挑戦的
使用シーン: フィットネス、スポーツアプリ
```

**HTML抜粋**:
```html
<section class="bg-gradient-to-br from-orange-50 to-white">
  <button class="bg-orange-500 text-white hover:bg-orange-600">
    無料で始める
  </button>
</section>
```

---

## CTA種別別事例

### 例8: 無料トライアル重視

**最適**: SaaS、サブスクリプションサービス

**CTA配置**:
```
1. ヘッダー: 「無料で始める」
2. ヒーロー: 「14日間無料トライアル」（メイン）
3. 特徴セクション後: 「今すぐ試す」
4. 最終CTA: 「無料トライアルを開始」
```

**コピー例**:
```
- クレジットカード不要
- いつでもキャンセル可能
- 全機能を14日間無料で試せます
```

---

### 例9: 資料ダウンロード重視

**最適**: BtoB、エンタープライズ、コンサルティング

**CTA配置**:
```
1. ヘッダー: 「資料請求」
2. ヒーロー: 「無料資料をダウンロード」（メイン）
3. 特徴セクション後: 「導入事例集を見る」
4. 最終CTA: 「今すぐ資料請求」
```

**リードマグネット例**:
```
- 導入事例集（PDF 20ページ）
- 比較表（競合他社との比較）
- ホワイトペーパー（業界レポート）
```

---

### 例10: 問い合わせ重視

**最適**: カスタムソリューション、高額商材

**CTA配置**:
```
1. ヘッダー: 「お問い合わせ」
2. ヒーロー: 「まずはご相談ください」（メイン）
3. 特徴セクション後: 「詳しく聞く」
4. 最終CTA: 「無料相談を予約」
```

**フォーム項目**:
```html
<form>
  <input type="text" placeholder="会社名">
  <input type="text" placeholder="お名前">
  <input type="email" placeholder="メールアドレス">
  <input type="tel" placeholder="電話番号">
  <textarea placeholder="お問い合わせ内容"></textarea>
  <button type="submit">送信する</button>
</form>
```

---

### 例11: デモ予約重視

**最適**: エンタープライズSaaS、複雑な製品

**CTA配置**:
```
1. ヘッダー: 「デモを予約」
2. ヒーロー: 「30分のデモを見る」（メイン）
3. 特徴セクション後: 「実際の動作を確認」
4. 最終CTA: 「今すぐデモを予約」
```

**予約システム統合例**:
```html
<!-- Calendly埋め込み例 -->
<div class="calendly-inline-widget"
     data-url="https://calendly.com/your-link"
     style="min-width:320px;height:630px;">
</div>
<script src="https://assets.calendly.com/assets/external/widget.js"></script>
```

---

## カスタマイズ事例

### 例12: カラー変更

**変更前**（緑系）:
```html
<button class="bg-green-500 hover:bg-green-600">
  無料トライアル
</button>
```

**変更後**（青系）:
```html
<button class="bg-blue-600 hover:bg-blue-700">
  無料トライアル
</button>
```

**一括置換**:
```bash
# VS Code / 検索置換
green-500 → blue-600
green-600 → blue-700
green-50  → blue-50
```

---

### 例13: 画像差し替え

**プレースホルダー**:
```html
<img src="https://placehold.co/600x400/10b981/white?text=Hero+Image"
     alt="ヒーロー画像">
```

**実際の画像**:
```html
<img src="./images/hero.jpg"
     alt="Miyabiダッシュボードのスクリーンショット"
     srcset="./images/hero-320w.jpg 320w,
             ./images/hero-640w.jpg 640w,
             ./images/hero-1024w.jpg 1024w"
     sizes="(max-width: 640px) 320px,
            (max-width: 1024px) 640px,
            1024px">
```

---

### 例14: セクション追加

**追加例: テストモニアル（顧客の声）**

```html
<section class="py-20 bg-gray-50">
  <div class="container mx-auto px-4">
    <h2 class="text-4xl font-bold text-center text-gray-900 mb-16">
      お客様の声
    </h2>
    <div class="grid md:grid-cols-3 gap-8">
      <!-- 顧客の声1 -->
      <div class="bg-white p-8 rounded-lg shadow-lg">
        <div class="flex items-center mb-4">
          <img src="./images/customer1.jpg"
               alt="山田太郎"
               class="w-12 h-12 rounded-full mr-4">
          <div>
            <div class="font-semibold">山田太郎</div>
            <div class="text-sm text-gray-600">株式会社ABC CEO</div>
          </div>
        </div>
        <p class="text-gray-600">
          「Miyabiを導入してから、開発スピードが2倍になりました。
          チーム全体の生産性が劇的に向上しています。」
        </p>
        <div class="flex mt-4">
          <svg class="w-5 h-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path>
          </svg>
          <!-- 5つ星表示 -->
        </div>
      </div>
      <!-- 顧客の声2, 3も同様 -->
    </div>
  </div>
</section>
```

---

### 例15: FAQ項目カスタマイズ

**デフォルト5項目から10項目に拡張**:

```html
<div class="space-y-4" x-data="{ open: null }">
  <!-- FAQ項目1 -->
  <div class="border border-gray-200 rounded-lg">
    <button @click="open = open === 1 ? null : 1"
            class="w-full px-6 py-4 text-left flex justify-between items-center">
      <span class="font-semibold text-lg">無料トライアルはありますか？</span>
      <svg class="w-5 h-5 transition-transform"
           :class="{ 'rotate-180': open === 1 }"
           fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>
    </button>
    <div x-show="open === 1" x-transition class="px-6 pb-4">
      <p class="text-gray-600">
        はい、14日間の無料トライアルをご用意しています。
        クレジットカード登録不要で全機能をお試しいただけます。
      </p>
    </div>
  </div>

  <!-- FAQ項目2-10も同様に追加 -->
</div>
```

---

## 高度なカスタマイズ

### 例16: アニメーション追加

**スクロールトリガーアニメーション**:

```html
<!-- Intersection Observer APIを使用 -->
<script>
document.addEventListener('DOMContentLoaded', function() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate-fade-in-up');
      }
    });
  });

  document.querySelectorAll('.animate-on-scroll').forEach((el) => {
    observer.observe(el);
  });
});
</script>

<style>
@keyframes fade-in-up {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in-up {
  animation: fade-in-up 0.6s ease-out;
}
</style>

<!-- 適用例 -->
<div class="animate-on-scroll">
  <h2>このセクションはスクロールでアニメーション</h2>
</div>
```

---

### 例17: フォーム統合（Netlify Forms）

```html
<form name="contact" method="POST" data-netlify="true">
  <input type="hidden" name="form-name" value="contact">

  <div class="mb-4">
    <label for="name" class="block text-sm font-medium text-gray-700 mb-2">
      お名前
    </label>
    <input type="text"
           id="name"
           name="name"
           required
           class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-600 focus:border-transparent">
  </div>

  <div class="mb-4">
    <label for="email" class="block text-sm font-medium text-gray-700 mb-2">
      メールアドレス
    </label>
    <input type="email"
           id="email"
           name="email"
           required
           class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-600 focus:border-transparent">
  </div>

  <button type="submit"
          class="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition">
    送信する
  </button>
</form>
```

---

### 例18: Google Analytics統合

```html
<!-- Google Analytics 4 -->
<head>
  <!-- Global site tag (gtag.js) - Google Analytics -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-XXXXXXXXXX');
  </script>
</head>
```

---

## まとめ

### 生成されるファイル構成

```
生成ディレクトリ/
├── index.html              # メインHTMLファイル
├── design-analysis.json    # デザイン分析結果
├── README.md              # カスタマイズガイド
└── (オプション)
    ├── images/            # 画像ディレクトリ（手動作成）
    ├── styles/            # カスタムCSS（必要に応じて）
    └── scripts/           # カスタムJS（必要に応じて）
```

### よくある質問

**Q1: 複数のLPを同時に生成できますか？**
A: 可能です。異なるディレクトリで複数回実行してください。

**Q2: 既存サイトのデザインを完全にコピーできますか？**
A: 構造とレイアウトは参考にしますが、オリジナルコンテンツとして生成されます。

**Q3: 商用利用可能ですか？**
A: はい、生成されたコードは自由に商用利用できます。

**Q4: バックエンド連携はできますか？**
A: フロントエンドのみです。バックエンドは別途実装が必要です。

**Q5: ダークモード対応できますか？**
A: 手動でTailwindCSSの`dark:`クラスを追加することで対応可能です。

---

**関連ドキュメント**:
- Agent仕様書: `.claude/agents/specs/business/lp-gen-agent.md`
- 実行プロンプト: `.claude/agents/prompts/business/lp-gen-agent-prompt.md`
- コマンドリファレンス: `.claude/commands/generate-lp.md`

---

**バージョン**: v1.0.0
**最終更新**: 2025-10-22
