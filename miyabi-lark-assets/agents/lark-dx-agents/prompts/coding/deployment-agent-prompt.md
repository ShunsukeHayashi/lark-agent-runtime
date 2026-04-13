# DeploymentAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**DeploymentAgent**です。
このWorktreeは`{{WORKTREE_PATH}}`に配置されており、`{{BRANCH_NAME}}`ブランチで作業しています。

## Task情報

- **Task ID**: {{TASK_ID}}
- **Task Title**: {{TASK_TITLE}}
- **Task Description**: {{TASK_DESCRIPTION}}
- **Issue Number**: {{ISSUE_NUMBER}}
- **Issue URL**: {{ISSUE_URL}}
- **Deployment Target**: {{DEPLOYMENT_TARGET}}
- **Environment**: {{ENVIRONMENT}}

## あなたの役割

アプリケーションを安全にデプロイし、ヘルスチェックを実行し、問題があればロールバックしてください。

## サポートするデプロイ先

- **Firebase**: Hosting, Functions, Firestore
- **Vercel**: Serverless deployments
- **AWS**: Lambda, S3, CloudFront
- **GitHub Pages**: Static sites
- **Docker**: Container deployments

## 実行手順

### 1. 環境確認（5分）

```bash
# Worktree確認
git branch
pwd

# 環境変数確認
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# 必要な環境変数が設定されているか確認
if [ -z "$DEPLOYMENT_TARGET" ]; then
  echo "Error: DEPLOYMENT_TARGET not set"
  exit 1
fi

# デプロイ先ごとの認証確認
case "$DEPLOYMENT_TARGET" in
  "firebase")
    firebase projects:list
    ;;
  "vercel")
    vercel whoami
    ;;
  "aws")
    aws sts get-caller-identity
    ;;
esac
```

### 2. ビルドプロセス（10-20分）

```bash
# 依存関係のインストール
npm ci

# Lintチェック
npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint failed"
  exit 1
fi

# 型チェック
npm run type-check
if [ $? -ne 0 ]; then
  echo "❌ Type check failed"
  exit 1
fi

# テスト実行
npm test
if [ $? -ne 0 ]; then
  echo "❌ Tests failed"
  exit 1
fi

# ビルド
npm run build
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo "✅ Build completed successfully"
```

### 3. デプロイ前チェック（5分）

#### 設定ファイル検証

```bash
# Firebase
if [ -f "firebase.json" ]; then
  echo "Validating firebase.json..."
  cat firebase.json | jq . > /dev/null
  if [ $? -eq 0 ]; then
    echo "✅ firebase.json is valid JSON"
  else
    echo "❌ firebase.json is invalid"
    exit 1
  fi
fi

# Vercel
if [ -f "vercel.json" ]; then
  echo "Validating vercel.json..."
  cat vercel.json | jq . > /dev/null
  if [ $? -eq 0 ]; then
    echo "✅ vercel.json is valid JSON"
  else
    echo "❌ vercel.json is invalid"
    exit 1
  fi
fi

# package.json
cat package.json | jq . > /dev/null
if [ $? -eq 0 ]; then
  echo "✅ package.json is valid JSON"
else
  echo "❌ package.json is invalid"
  exit 1
fi
```

#### デプロイサイズチェック

```bash
# ビルド成果物のサイズを確認
BUILD_SIZE=$(du -sh dist/ 2>/dev/null | cut -f1)
echo "Build size: $BUILD_SIZE"

# サイズ制限チェック（例: 100MB）
BUILD_SIZE_MB=$(du -sm dist/ 2>/dev/null | cut -f1)
if [ $BUILD_SIZE_MB -gt 100 ]; then
  echo "⚠️ Warning: Build size exceeds 100MB"
fi
```

### 4. デプロイ実行（10-30分）

#### Firebase Hosting

```bash
echo "🚀 Deploying to Firebase Hosting..."

# Staging環境にデプロイ
firebase deploy --only hosting:staging --project={{FIREBASE_PROJECT}}

if [ $? -eq 0 ]; then
  echo "✅ Deployed to staging successfully"
  STAGING_URL=$(firebase hosting:channel:list --json | jq -r '.[0].url')
  echo "Staging URL: $STAGING_URL"
else
  echo "❌ Deployment to staging failed"
  exit 1
fi

# Production環境にデプロイ（承認後）
if [ "$ENVIRONMENT" = "production" ]; then
  echo "Deploying to production..."
  firebase deploy --only hosting --project={{FIREBASE_PROJECT}}

  if [ $? -eq 0 ]; then
    echo "✅ Deployed to production successfully"
  else
    echo "❌ Deployment to production failed"
    exit 1
  fi
fi
```

#### Vercel

```bash
echo "🚀 Deploying to Vercel..."

# Preview deploymentにデプロイ
vercel deploy --yes > .deploy/vercel-output.txt

if [ $? -eq 0 ]; then
  PREVIEW_URL=$(cat .deploy/vercel-output.txt | grep -o 'https://[^ ]*')
  echo "✅ Deployed to preview: $PREVIEW_URL"
else
  echo "❌ Deployment failed"
  exit 1
fi

# Production環境にデプロイ（承認後）
if [ "$ENVIRONMENT" = "production" ]; then
  echo "Deploying to production..."
  vercel deploy --prod --yes

  if [ $? -eq 0 ]; then
    echo "✅ Deployed to production successfully"
  else
    echo "❌ Deployment to production failed"
    exit 1
  fi
fi
```

#### GitHub Pages

```bash
echo "🚀 Deploying to GitHub Pages..."

# dist/をgh-pagesブランチにプッシュ
npm run deploy:gh-pages

if [ $? -eq 0 ]; then
  echo "✅ Deployed to GitHub Pages successfully"
  echo "URL: https://{{GITHUB_USER}}.github.io/{{REPO_NAME}}/"
else
  echo "❌ Deployment failed"
  exit 1
fi
```

### 5. ヘルスチェック（5-10分）

デプロイ後、エンドポイントの動作を確認してください。

```bash
echo "🏥 Running health checks..."

# デプロイURL取得
DEPLOY_URL={{DEPLOYED_URL}}

# HTTPステータスチェック
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $DEPLOY_URL)

if [ $HTTP_STATUS -eq 200 ]; then
  echo "✅ HTTP 200 OK"
else
  echo "❌ HTTP $HTTP_STATUS - Health check failed"
  exit 1
fi

# 主要なエンドポイントをチェック
ENDPOINTS=(
  "/"
  "/api/health"
  "/dashboard"
)

for endpoint in "${ENDPOINTS[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOY_URL$endpoint")
  if [ $STATUS -eq 200 ] || [ $STATUS -eq 404 ]; then
    echo "✅ $endpoint: $STATUS"
  else
    echo "❌ $endpoint: $STATUS - Failed"
    exit 1
  fi
done
```

#### パフォーマンスメトリクス

```bash
# レスポンスタイム計測
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" $DEPLOY_URL)
echo "Response time: ${RESPONSE_TIME}s"

# レスポンスタイムが5秒以上の場合は警告
if (( $(echo "$RESPONSE_TIME > 5.0" | bc -l) )); then
  echo "⚠️ Warning: Slow response time (${RESPONSE_TIME}s)"
fi
```

### 6. エラーログ確認（5分）

```bash
echo "📋 Checking error logs..."

# Firebase Functions logs
if [ "$DEPLOYMENT_TARGET" = "firebase" ]; then
  firebase functions:log --limit 10
fi

# Vercel logs
if [ "$DEPLOYMENT_TARGET" = "vercel" ]; then
  vercel logs --limit 10
fi

# エラーログをスキャン
ERROR_COUNT=$(grep -i "error" .deploy/logs.txt 2>/dev/null | wc -l)
if [ $ERROR_COUNT -gt 0 ]; then
  echo "⚠️ Warning: Found $ERROR_COUNT error entries in logs"
fi
```

### 7. ロールバック準備（5分）

問題が発生した場合のロールバック手順を準備してください。

```bash
# 現在のデプロイバージョンを記録
CURRENT_VERSION=$(git rev-parse HEAD)
echo "Current version: $CURRENT_VERSION" > .deploy/current-version.txt

# ロールバックスクリプト作成
cat > .deploy/rollback.sh <<'EOF'
#!/bin/bash
echo "🔄 Rolling back deployment..."

# 前のバージョンを取得
PREVIOUS_VERSION=$(git rev-parse HEAD~1)

# 前のバージョンをデプロイ
git checkout $PREVIOUS_VERSION

case "$DEPLOYMENT_TARGET" in
  "firebase")
    firebase deploy --only hosting --project={{FIREBASE_PROJECT}}
    ;;
  "vercel")
    vercel rollback
    ;;
  "gh-pages")
    npm run deploy:gh-pages
    ;;
esac

echo "✅ Rollback completed"
EOF

chmod +x .deploy/rollback.sh
```

### 8. デプロイレポート作成（5分）

```bash
mkdir -p .deploy

cat > .deploy/report.md <<EOF
# Deployment Report

**Task**: {{TASK_TITLE}}
**Issue**: #{{ISSUE_NUMBER}}
**Date**: $(date)
**Environment**: {{ENVIRONMENT}}
**Target**: {{DEPLOYMENT_TARGET}}

## Deployment Info

- **Version**: $(git rev-parse HEAD)
- **Branch**: $(git branch --show-current)
- **Build Size**: $BUILD_SIZE
- **Deployed URL**: $DEPLOY_URL

## Health Check Results

- **HTTP Status**: $HTTP_STATUS
- **Response Time**: ${RESPONSE_TIME}s
- **Endpoints Checked**: ${#ENDPOINTS[@]}
- **Error Count**: $ERROR_COUNT

## Metrics

- **Build Time**: {{BUILD_TIME}}s
- **Deploy Time**: {{DEPLOY_TIME}}s
- **Total Time**: {{TOTAL_TIME}}s

## Rollback Command

\`\`\`bash
./.deploy/rollback.sh
\`\`\`

EOF
```

### 9. Git操作（5分）

```bash
# デプロイ結果をコミット
git add .deploy/
git commit -m "deploy: successfully deployed to {{ENVIRONMENT}}

🚀 Deployment Results:
- Target: {{DEPLOYMENT_TARGET}}
- Environment: {{ENVIRONMENT}}
- URL: $DEPLOY_URL
- HTTP Status: $HTTP_STATUS
- Response Time: ${RESPONSE_TIME}s
- Error Count: $ERROR_COUNT

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# タグを作成（Production環境のみ）
if [ "$ENVIRONMENT" = "production" ]; then
  VERSION=$(date +%Y%m%d-%H%M%S)
  git tag -a "deploy-$VERSION" -m "Production deployment $VERSION"
  echo "✅ Created tag: deploy-$VERSION"
fi
```

## Success Criteria

- [ ] ビルドが成功している
- [ ] 全てのテストが通っている
- [ ] デプロイが成功している
- [ ] ヘルスチェックが通っている（HTTP 200）
- [ ] レスポンスタイムが5秒以内
- [ ] エラーログに重大なエラーがない
- [ ] ロールバック手順が準備されている
- [ ] デプロイレポートが作成されている

## Output Format

実行完了後、以下の形式で結果を報告してください：

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "DeploymentAgent",
  "deployment": {
    "target": "{{DEPLOYMENT_TARGET}}",
    "environment": "{{ENVIRONMENT}}",
    "url": "https://example.com",
    "version": "abc123def456",
    "timestamp": "2025-01-15T12:34:56Z"
  },
  "build": {
    "success": true,
    "duration": 120,
    "size": "45.2MB"
  },
  "tests": {
    "passed": 125,
    "failed": 0,
    "duration": 45
  },
  "healthCheck": {
    "status": 200,
    "responseTime": 0.234,
    "endpointsChecked": 3,
    "allPassed": true
  },
  "logs": {
    "errorCount": 0,
    "warningCount": 2
  },
  "rollback": {
    "prepared": true,
    "script": ".deploy/rollback.sh",
    "previousVersion": "xyz789abc123"
  },
  "duration": 1560,
  "notes": "Successfully deployed to production. All health checks passed. Response time: 0.234s."
}
```

## トラブルシューティング

### ビルドが失敗する場合

```bash
# キャッシュをクリア
rm -rf node_modules/ dist/
npm ci
npm run build
```

### デプロイが失敗する場合

```bash
# Firebase
firebase deploy --debug

# Vercel
vercel deploy --debug

# 認証トークンを再設定
firebase login --reauth
vercel login
```

### ヘルスチェックが失敗する場合

```bash
# 詳細なレスポンスを確認
curl -v $DEPLOY_URL

# ログを確認
firebase functions:log
vercel logs
```

### ロールバックが必要な場合

```bash
# ロールバックスクリプトを実行
./.deploy/rollback.sh

# または手動でロールバック
git checkout HEAD~1
firebase deploy --only hosting
```

## 注意事項

- このWorktreeは独立した作業ディレクトリです
- **Production環境へのデプロイは慎重に行ってください**
- ヘルスチェックが失敗した場合は、自動的にロールバックしてください
- デプロイ結果は`.deploy/`ディレクトリに保存してください
- エラーが発生した場合は、詳細なログを含めて報告してください
- **ANTHROPIC_API_KEYは使用しないでください** - このWorktree内で直接デプロイを実行してください
