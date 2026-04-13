# ImageGenAgent 仕様書

**Agent ID**: `imagegen`
**Agent Type**: Coding Agent
**Version**: 1.0.0
**Status**: Active

---

## 📋 概要

**ImageGenAgent**は、Text-to-Image (T2I) 生成とImage-to-Image編集を担当する専門Agentです。BytePlus ARK API (`seedream-4-0-250828`) を使用して、プレゼンテーション資料、ドキュメント、マーケティング素材などに必要な画像を自動生成・編集します。

---

## 🎯 責任範囲

### 主要タスク

1. **Text-to-Image生成**
   - プロンプトから新規画像を生成
   - 複数サイズ対応（256x256 ~ 2048x2048）
   - バッチ生成（複数画像の一括生成）

2. **Image-to-Image編集**
   - 既存画像の最適化・強化
   - スタイル変換（プロフェッショナル、カジュアル、アート等）
   - 背景変更・照明調整

3. **プレゼンテーション統合**
   - HTML/CSS/JSへの画像統合
   - レスポンシブ対応
   - 最適化（圧縮、フォーマット変換）

4. **品質管理**
   - 生成画像の品質チェック
   - プロンプト最適化提案
   - 再生成推奨

---

## 🔧 実行条件

### 必須条件

- [ ] `BYTEPLUS_API_KEY` 環境変数が設定されている
- [ ] Node.js v14+ がインストールされている
- [ ] 出力ディレクトリ `images/` が存在する（または自動作成）

### オプション条件

- [ ] ImageMagickがインストールされている（最適化用）
- [ ] TinyPNGアカウント（追加圧縮用）

---

## 📊 入力仕様

### Task Input Schema

```json
{
  "taskType": "imagegen",
  "operation": "generate" | "edit" | "batch",
  "images": [
    {
      "id": "unique-image-id",
      "filename": "output-filename.png",
      "prompt": "Detailed image generation prompt",
      "width": 1024,
      "height": 1024,
      "sourceImage": "path/to/source.jpg" // For edit operation only
    }
  ],
  "config": {
    "model": "seedream-4-0-250828",
    "responseFormat": "b64_json" | "url",
    "watermark": false,
    "rateLimitDelay": 2000
  }
}
```

### Example: Text-to-Image Generation

```json
{
  "taskType": "imagegen",
  "operation": "generate",
  "images": [
    {
      "id": "profile-photo",
      "filename": "profile-professional.png",
      "prompt": "Professional portrait of Hayashi Shunsuke, Japanese software engineer, business casual attire, friendly smile, studio lighting, high quality",
      "width": 400,
      "height": 400
    }
  ]
}
```

### Example: Image-to-Image Edit

```json
{
  "taskType": "imagegen",
  "operation": "edit",
  "images": [
    {
      "id": "profile-enhance",
      "filename": "profile-enhanced.png",
      "prompt": "Enhance lighting and contrast, add gradient background (purple to pink), professional presentation style",
      "width": 1024,
      "height": 1024,
      "sourceImage": "source-profile.jpg"
    }
  ]
}
```

---

## 📤 出力仕様

### Success Output

```json
{
  "status": "success",
  "agentId": "imagegen",
  "executionTime": "25.3s",
  "results": [
    {
      "imageId": "profile-photo",
      "filename": "profile-professional.png",
      "path": "/path/to/images/profile-professional.png",
      "size": "128.5 KB",
      "dimensions": "400x400",
      "generatedAt": "2025-10-22T14:30:00Z"
    }
  ],
  "summary": {
    "totalImages": 1,
    "successCount": 1,
    "failCount": 0
  }
}
```

### Error Output

```json
{
  "status": "error",
  "agentId": "imagegen",
  "errorType": "API_ERROR" | "VALIDATION_ERROR" | "FILE_ERROR",
  "message": "API Error: Invalid API key",
  "failedImages": ["profile-photo"],
  "suggestions": [
    "Check BYTEPLUS_API_KEY environment variable",
    "Verify API quota"
  ]
}
```

---

## 🔄 ワークフロー

### Standard Workflow

```
1. Task受信
   ↓
2. 入力検証（APIキー、プロンプト、サイズ）
   ↓
3. レート制限チェック（前回実行から2秒経過）
   ↓
4. API呼び出し（BytePlus ARK）
   ↓
5. レスポンス処理（Base64デコード）
   ↓
6. ファイル保存（images/ディレクトリ）
   ↓
7. 品質チェック（ファイルサイズ、次元確認）
   ↓
8. 結果返却
```

### Batch Workflow

```
1. バッチTask受信（複数画像）
   ↓
2. 各画像に対してシーケンシャル処理
   ↓
3. 2秒間隔でレート制限適用
   ↓
4. 進捗報告（n/total完了）
   ↓
5. 全体サマリー返却
```

---

## ⚠️ エスカレーション条件

### Immediate Escalation (重大)

1. **APIキー無効**
   - 条件: `BYTEPLUS_API_KEY`が設定されていない、または無効
   - 対応: CoordinatorAgentにエスカレーション、タスク中断
   - エラーコード: `ERR_IMAGEGEN_001`

2. **API完全障害**
   - 条件: APIが5回連続で失敗
   - 対応: CoordinatorAgentにエスカレーション、別のT2Iサービス検討
   - エラーコード: `ERR_IMAGEGEN_002`

3. **クォータ超過**
   - 条件: APIクォータ制限に到達
   - 対応: CoordinatorAgentにエスカレーション、翌日再試行
   - エラーコード: `ERR_IMAGEGEN_003`

### Warning Level (警告)

1. **画像品質低下**
   - 条件: 生成画像のファイルサイズが異常に小さい（< 10KB）
   - 対応: 警告ログ記録、プロンプト改善提案

2. **レート制限近接**
   - 条件: 短時間に大量のリクエスト
   - 対応: 自動遅延増加（2秒 → 5秒）

---

## 🔐 権限・制約

### 実行権限

- ✅ `images/` ディレクトリへの書き込み
- ✅ 環境変数 `BYTEPLUS_API_KEY` の読み取り
- ✅ HTTPS通信（BytePlus ARK API）

### 制約事項

- ❌ 他のディレクトリへの書き込み禁止
- ❌ システムファイルの変更禁止
- ❌ ユーザー入力のAPIキーの保存禁止（環境変数のみ）

---

## 📈 パフォーマンス指標

### 目標値

| 指標 | 目標値 |
|------|--------|
| 画像生成時間 | < 10秒/枚 |
| バッチ処理効率 | 90%以上の成功率 |
| APIエラー率 | < 5% |
| 品質スコア | > 85/100 |

### モニタリング

- 生成時間のログ記録
- エラー率の追跡
- APIクォータ使用量の監視

---

## 🧪 テスト要件

### 単体テスト

```typescript
describe('ImageGenAgent', () => {
  test('should generate image from text prompt', async () => {
    const task = {
      operation: 'generate',
      images: [{
        id: 'test-image',
        filename: 'test.png',
        prompt: 'A simple blue circle',
        width: 256,
        height: 256
      }]
    };
    const result = await imageGenAgent.execute(task);
    expect(result.status).toBe('success');
    expect(fs.existsSync('images/test.png')).toBe(true);
  });

  test('should handle API errors gracefully', async () => {
    process.env.BYTEPLUS_API_KEY = 'invalid-key';
    const task = { /* ... */ };
    const result = await imageGenAgent.execute(task);
    expect(result.status).toBe('error');
    expect(result.errorType).toBe('API_ERROR');
  });
});
```

### 統合テスト

- CoordinatorAgent → ImageGenAgent のタスク委譲
- 生成画像のHTMLへの統合確認
- レスポンシブデザイン対応確認

---

## 📚 依存関係

### 外部API

- **BytePlus ARK API** (必須)
  - Model: `seedream-4-0-250828`
  - Endpoint: `https://ark.ap-southeast.bytepluses.com/api/v3/images/generations`
  - 認証: Bearer Token

### Node.js標準ライブラリ

- `https` - HTTPS通信
- `fs` - ファイル操作
- `path` - パス処理

### オプションツール

- ImageMagick - 画像最適化
- TinyPNG API - 追加圧縮

---

## 🔄 他Agentとの連携

### → CoordinatorAgent

- ImageGenAgent実行の依頼を受ける
- エスカレーション報告

### → DeploymentAgent

- 生成画像をデプロイパッケージに含める
- 静的ファイル配信設定

### ← ReviewAgent

- 生成画像の品質レビュー依頼
- プロンプト改善提案の受領

---

## 📝 ログ出力

### 標準ログフォーマット

```
[2025-10-22 14:30:00] [ImageGenAgent] [INFO] Starting image generation: profile-photo
[2025-10-22 14:30:05] [ImageGenAgent] [SUCCESS] Generated: profile-professional.png (128.5 KB)
[2025-10-22 14:30:05] [ImageGenAgent] [INFO] Execution completed in 5.2s
```

### エラーログフォーマット

```
[2025-10-22 14:30:00] [ImageGenAgent] [ERROR] API_ERROR: Invalid API key
[2025-10-22 14:30:00] [ImageGenAgent] [ERROR] Failed image: profile-photo
[2025-10-22 14:30:00] [ImageGenAgent] [ESCALATION] Escalating to CoordinatorAgent
```

---

## 🚀 使用例

### CLI実行

```bash
# 単一画像生成
miyabi agent run imagegen --task-file task.json

# バッチ生成
miyabi agent run imagegen --batch images-config.json

# Image編集
miyabi agent run imagegen --edit source.jpg --prompt "Enhance lighting" --output enhanced.png
```

### プログラマティック実行

```typescript
import { ImageGenAgent } from 'miyabi-agents';

const agent = new ImageGenAgent({
  apiKey: process.env.BYTEPLUS_API_KEY,
  outputDir: './images'
});

const task = {
  operation: 'generate',
  images: [{ /* ... */ }]
};

const result = await agent.execute(task);
console.log(result);
```

---

## 📌 更新履歴

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-22 | 初版作成 - T2I & Image Edit機能 |

---

**作成日**: 2025-10-22
**作成者**: Claude Code (AI Assistant)
**ステータス**: Active
