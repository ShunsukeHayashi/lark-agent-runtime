# SlideGenAgent実行プロンプト

**Agent**: SlideGenAgent（すらいだー）
**カテゴリ**: Business Agent（15個目）
**バージョン**: v1.0.0

---

## 📋 このプロンプトの目的

このプロンプトは、Claude CodeがWorktree環境でSlideGenAgentを実行する際に使用します。
AI駆動でプレゼンテーションスライドを自動生成し、品質評価を行います。

---

## 🎯 実行手順

### Phase 1: コンテキスト確認

1. **実行コンテキストファイルを読む**
   ```bash
   cat .agent-context.json
   cat EXECUTION_CONTEXT.md
   ```

2. **Task情報を確認**
   - タスクタイプ: `slide-generation`
   - トピック: `{task.metadata.topic}`
   - スライド数: `{task.metadata.slide_count}`
   - テーマ: `{task.metadata.theme}` (apple/classic/dark/modern)
   - 対象: `{task.metadata.audience}`

3. **環境変数を確認**
   ```bash
   echo $BYTEPLUS_API_KEY  # BytePlus ARK API Key
   echo $GITHUB_TOKEN      # GitHub API Token（オプション）
   ```

---

### Phase 2: アウトライン生成

1. **トピック分析**
   - プレゼンテーショントピックのキーワード抽出
   - ターゲットオーディエンスの理解
   - スライド構成の計画

2. **アウトライン作成**
   ```json
   {
     "title": "プレゼンテーションタイトル",
     "subtitle": "サブタイトル",
     "author": "発表者名",
     "event": "イベント名",
     "date": "2025-10-22",
     "sections": [
       {
         "title": "セクション1",
         "slides": [
           {
             "type": "title",
             "content": "タイトルスライド",
             "notes": "発表者ノート"
           },
           {
             "type": "intro",
             "content": "自己紹介",
             "notes": "発表者の経歴"
           }
         ]
       }
     ]
   }
   ```

3. **アウトライン保存**
   ```bash
   cat > outline.json <<'EOF'
   {アウトライン内容}
   EOF
   ```

---

### Phase 3: スライド生成

1. **テーマファイル準備**
   ```bash
   # テーマCSSをコピー
   cp ../../../docs/conferences/slides/styles-{theme}.css ./styles-{theme}.css
   cp ../../../docs/conferences/slides/script.js ./script.js
   ```

2. **HTMLファイル生成**
   - Reveal.js 4.5.0をCDNから読み込み
   - 選択されたテーマCSSを適用
   - アウトラインに基づいてスライドHTMLを生成

   **HTMLテンプレート構造**:
   ```html
   <!DOCTYPE html>
   <html lang="ja">
   <head>
       <meta charset="utf-8">
       <title>{プレゼンテーションタイトル}</title>
       <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/reveal.js@4.5.0/dist/reveal.min.css">
       <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/reveal.js@4.5.0/dist/theme/white.min.css">
       <link rel="stylesheet" href="styles-{theme}.css">
   </head>
   <body>
       <div class="reveal">
           <div class="slides">
               <!-- スライド生成 -->
           </div>
       </div>
       <script src="https://cdn.jsdelivr.net/npm/reveal.js@4.5.0/dist/reveal.min.js"></script>
       <script src="script.js"></script>
   </body>
   </html>
   ```

3. **スライドタイプごとの生成**

   #### Type: `title` (タイトルスライド)
   ```html
   <section class="title-slide">
       <div class="title-content">
           <div class="miyabi-logo">
               <svg class="miyabi-logo-icon">...</svg>
               <h1 class="main-title">{タイトル}</h1>
           </div>
           <p class="session-title">{セッションタイトル}</p>
           <p class="subtitle">{サブタイトル}</p>
           <div class="speaker-info">
               <p class="speaker-name">{発表者名}</p>
               <p class="event-name">{イベント名}</p>
               <p class="event-date">{日付}</p>
           </div>
       </div>
   </section>
   ```

   #### Type: `intro` (自己紹介)
   ```html
   <section class="intro-slide">
       <h2>自己紹介</h2>
       <div class="intro-grid">
           <div class="intro-left">
               <div class="profile-photo">
                   <img src="{プロフィール画像URL}" alt="Profile">
               </div>
           </div>
           <div class="intro-right">
               <ul class="intro-list">
                   <li><strong>名前:</strong> {発表者名}</li>
                   <li><strong>所属:</strong> {所属組織}</li>
                   <li><strong>専門:</strong> {専門分野}</li>
               </ul>
           </div>
       </div>
   </section>
   ```

   #### Type: `problem` (問題提起)
   ```html
   <section>
       <h2>問題提起</h2>
       <p>{問題の説明}</p>
       <ul>
           <li>{問題点1}</li>
           <li>{問題点2}</li>
           <li>{問題点3}</li>
       </ul>
   </section>
   ```

   #### Type: `solution` (解決策)
   ```html
   <section>
       <h2>解決策</h2>
       <p>{解決策の説明}</p>
       <ul>
           <li>{特徴1}</li>
           <li>{特徴2}</li>
           <li>{特徴3}</li>
       </ul>
   </section>
   ```

   #### Type: `statistics` (統計データ)
   ```html
   <section>
       <h2>データで見る問題</h2>
       <div class="statistics-grid">
           <div class="stat-card">
               <h3>{数値1}</h3>
               <p>{説明1}</p>
           </div>
           <div class="stat-card">
               <h3>{数値2}</h3>
               <p>{説明2}</p>
           </div>
       </div>
   </section>
   ```

   #### Type: `qna` (Q&A・連絡先)
   ```html
   <section class="qna-slide">
       <h1>Q&A</h1>
       <p class="qna-subtitle">ご質問・ご連絡</p>
       <div class="contact-info">
           <div class="link-grid">
               <a href="{Twitter URL}" class="contact-link">Twitter</a>
               <a href="{GitHub URL}" class="contact-link">GitHub</a>
               <a href="{Email URL}" class="contact-link">Email</a>
           </div>
       </div>
   </section>
   ```

---

### Phase 4: 画像生成（オプション）

1. **画像が必要なスライドを特定**
   - `intro` (プロフィール写真)
   - `problem` (視覚的メタファー)
   - `solution` (アーキテクチャ図)
   - `demo` (スクリーンショット)

2. **BytePlus ARK T2I API呼び出し**
   ```bash
   curl -X POST https://ark.ap-southeast.bytepluses.com/api/v3/images/generations \
     -H "Authorization: Bearer $BYTEPLUS_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "seedream-4-0-250828",
       "prompt": "{最適化されたプロンプト}",
       "size": "1920x1080",
       "response_format": "b64_json"
     }' > image_response.json
   ```

3. **Base64画像をデコードして保存**
   ```bash
   jq -r '.data[0].b64_json' image_response.json | base64 -d > images/{image_name}.png
   ```

4. **HTMLに画像パスを埋め込み**
   ```html
   <img src="images/{image_name}.png" alt="{alt text}">
   ```

---

### Phase 5: 品質評価

1. **Content Score評価**
   - テキスト長チェック（50-500文字が最適）
   - 見出し構造チェック（H1/H2の存在）
   - リスト構造チェック（UL/OLの存在）
   - 段落数チェック（1-3個が最適）

2. **Design Score評価**
   - 視覚要素チェック（画像/SVGの存在）
   - コードブロックチェック
   - アニメーションチェック
   - アイコンチェック
   - カスタム背景チェック

3. **Coherence Score評価**
   - 前後スライドの論理的つながり
   - トピックの一貫性
   - 構造的フロー

4. **品質レポート生成**
   ```bash
   cat > quality_report.json <<'EOF'
   {
     "overall_score": 85,
     "grade": "B+",
     "slides": [
       {
         "slide_index": 0,
         "content_score": 90,
         "design_score": 85,
         "coherence_score": 90,
         "overall": 88,
         "recommendations": ["画像を追加してDesign Scoreを向上"]
       }
     ],
     "low_quality_slides": [3, 7, 12],
     "improvement_actions": [
       "Slide 3: コンテンツを200文字以上に増やす",
       "Slide 7: 画像またはアイコンを追加",
       "Slide 12: リスト構造を追加"
     ]
   }
   EOF
   ```

---

### Phase 6: エクスポート

1. **HTML保存**
   ```bash
   mv index.html presentation.html
   ```

2. **PDF生成（オプション）**
   ```bash
   # Reveal.js PDF exportを使用
   # ブラウザで ?print-pdf を付けてアクセス後、印刷
   ```

3. **PPTX生成（オプション）**
   ```bash
   # python-pptxを使用（将来実装）
   python3 convert_to_pptx.py presentation.html -o presentation.pptx
   ```

---

### Phase 7: Git Commit

1. **ファイルをステージング**
   ```bash
   git add index.html styles-{theme}.css script.js outline.json quality_report.json
   git add images/*.png  # 画像がある場合
   ```

2. **Conventional Commits形式でコミット**
   ```bash
   git commit -m "$(cat <<'EOF'
   feat(business-agent): add SlideGenAgent - AI-driven presentation generator

   - Generated {slide_count} slides on topic: {topic}
   - Theme: {theme}
   - Overall Quality Score: {score}/100 (Grade: {grade})
   - Low quality slides: {count} (auto-improvement recommended)

   Agent: SlideGenAgent (すらいだー)
   Inspired by: PPTAgent (EMNLP 2025), presentation-ai, ChatPPT

   🤖 Generated with Miyabi SlideGenAgent
   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

3. **ブランチをプッシュ**
   ```bash
   git push -u origin HEAD
   ```

---

## 🔍 チェックリスト

### 実行前

- [ ] `.agent-context.json`を読んで確認
- [ ] `EXECUTION_CONTEXT.md`を読んで確認
- [ ] `BYTEPLUS_API_KEY`環境変数を確認
- [ ] タスクメタデータ（topic, slide_count, theme）を確認

### Phase 1: アウトライン生成

- [ ] トピック分析完了
- [ ] セクション構成決定
- [ ] スライドタイプ割り当て
- [ ] `outline.json`保存

### Phase 2-3: スライド生成

- [ ] テーマCSSコピー
- [ ] `script.js`コピー
- [ ] HTML生成（全スライド）
- [ ] タイトルスライド生成
- [ ] 自己紹介スライド生成
- [ ] コンテンツスライド生成
- [ ] Q&Aスライド生成

### Phase 4: 画像生成（オプション）

- [ ] 必要な画像リスト作成
- [ ] BytePlus ARK API呼び出し
- [ ] 画像保存（`images/`ディレクトリ）
- [ ] HTMLに画像パス埋め込み

### Phase 5: 品質評価

- [ ] Content Score計算
- [ ] Design Score計算
- [ ] Coherence Score計算
- [ ] 品質レポート生成（`quality_report.json`）
- [ ] 低品質スライド特定
- [ ] 改善アクション提案

### Phase 6: エクスポート

- [ ] HTML保存
- [ ] PDF生成（オプション）
- [ ] PPTX生成（オプション）

### Phase 7: Git Commit

- [ ] ファイルをステージング
- [ ] Conventional Commits形式でコミット
- [ ] ブランチをプッシュ

---

## ⚠️ エラーハンドリング

### Error 1: BytePlus ARK API Rate Limit

**症状**: `429 Too Many Requests`
**対策**:
1. 2秒間待機後にリトライ
2. 最大3回リトライ
3. 失敗した場合はエスカレーション

```bash
for i in {1..3}; do
    response=$(curl -X POST ... 2>/dev/null)
    if [ $? -eq 0 ]; then
        break
    fi
    echo "Retry $i/3..."
    sleep 2
done
```

### Error 2: 画像生成失敗

**症状**: `500 Internal Server Error`
**対策**:
1. プロンプトを短縮（80文字以内）
2. 画像サイズを変更（1024x1024）
3. 画像なしで続行（デザインスコアは下がるが生成は完了）

### Error 3: 品質スコア低下

**症状**: Overall Score < 60
**対策**:
1. 低品質スライドを特定
2. コンテンツを追加（テキスト長を増やす）
3. 構造を改善（リスト、見出しを追加）
4. 再評価

### Error 4: Reveal.js読み込み失敗

**症状**: スライドが表示されない
**対策**:
1. CDN URLを確認
2. ローカルにReveal.jsバンドルを配置
3. `<script>` タグのパスを修正

---

## 📊 品質基準

### 最低品質基準

- **Overall Score**: 70点以上
- **Content Score**: 60点以上
- **Design Score**: 60点以上
- **Coherence Score**: 70点以上

### 推奨品質基準

- **Overall Score**: 85点以上
- **Content Score**: 80点以上
- **Design Score**: 80点以上
- **Coherence Score**: 85点以上

### エスカレーション基準

以下の場合は、CoordinatorAgentまたはユーザーへエスカレーション：

- Overall Score < 60（3回再生成しても改善しない）
- 画像生成が連続3回失敗
- BytePlus ARK APIが連続5回失敗
- テーマCSSが読み込めない

---

## 🎨 テーマ別の注意事項

### Apple Theme
- **特徴**: ミニマル、白ベース、Apple風
- **注意**: 画像は最小限、テキスト中心
- **フォント**: Inter（Apple SF Pro代替）
- **色**: 白背景、黒テキスト、ブルーアクセント

### Classic Theme
- **特徴**: 伝統的、ビジネス、保守的
- **注意**: フォーマル、アニメーションなし
- **フォント**: Merriweather（見出し）、Open Sans（本文）
- **色**: グレー背景、ネイビーテキスト、ブルーアクセント

### Dark Theme
- **特徴**: ダークモード、ハイコントラスト
- **注意**: 視認性重視、グローエフェクト
- **フォント**: Inter
- **色**: 黒背景、白テキスト、シアンアクセント

### Modern Theme
- **特徴**: グラデーション、ガラスモーフィズム
- **注意**: 視覚的インパクト、複雑なアニメーション
- **フォント**: Inter
- **色**: 紫・ピンクグラデーション

---

## 🚀 実行例

### 例1: 技術カンファレンス向けスライド

**Input**:
```json
{
  "topic": "Miyabi - 完全自律型AI開発OS",
  "slide_count": 30,
  "theme": "apple",
  "audience": "技術カンファレンス"
}
```

**Output**:
- `index.html` (30スライド、Appleテーマ)
- `quality_report.json` (Overall Score: 88/100, Grade: B+)
- `outline.json`
- `images/` (7枚の画像)

### 例2: ビジネスプレゼン向けスライド

**Input**:
```json
{
  "topic": "新規事業提案 - AI自動化プラットフォーム",
  "slide_count": 20,
  "theme": "classic",
  "audience": "経営層"
}
```

**Output**:
- `index.html` (20スライド、Classicテーマ)
- `quality_report.json` (Overall Score: 82/100, Grade: B)
- `outline.json`

---

## 📚 参考ドキュメント

- [SlideGenAgent仕様書](../../specs/business/slide-gen-agent.md)
- [AI_PRESENTATION_RESEARCH.md](../../../../docs/conferences/slides/AI_PRESENTATION_RESEARCH.md)
- [PPTAgent Paper](https://github.com/icip-cas/PPTAgent)
- [Reveal.js Documentation](https://revealjs.com/)

---

## ✅ 完了条件

以下がすべて満たされたら、タスク完了：

- [x] `index.html`生成完了
- [x] 品質評価完了（Overall Score >= 70）
- [x] `quality_report.json`生成完了
- [x] Git commit完了
- [x] ブランチpush完了
- [x] エラーなし、またはエスカレーション済み

---

**実行者**: Claude Code
**Agent**: SlideGenAgent（すらいだー）
**最終更新**: 2025-10-22
