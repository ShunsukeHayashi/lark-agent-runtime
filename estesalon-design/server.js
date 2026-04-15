/**
 * みやびAIサロン — MVP サーバー
 *
 * アーキテクチャ:
 *   チャットUI (chat.html)
 *     ↕ HTTP POST /api/chat
 *   Express サーバー (server.js)
 *     ↕ Anthropic SDK (ZAI proxy)
 *   Claude AI (tool use)
 *     ↕ Lark Open API
 *   Lark Base (顧客台帳・予約台帳・メニュー・活動ログ)
 */

const express = require('express');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

const BASE_TOKEN = 'J2zebbp6VaUfEhsjdC6jxxMapob';
const TBL_CUSTOMER = 'tblgfKSL40Xep9ee';
const TBL_BOOKING = 'tblj6yT5JShzYAJ0';
const TBL_MENU = 'tblayqdqqQOyKqIV';
const TBL_LOG = 'tblETOMdaWRnnQdv';

const LARK_ERROR_MESSAGE = 'Lark Baseに接続できませんでした';
const TOKEN_SAFETY_WINDOW_MS = 60 * 1000;
const tokenCache = { value: null, expiresAt: 0 };

const TOOLS = [
  {
    name: 'get_reservations',
    description: '予約台帳から指定日の予約一覧を取得する。「今日の予約は？」「明日は何件？」などに対応。',
    input_schema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'YYYY/MM/DD形式の日付。省略すると今日の日付を使用。' }
      }
    }
  },
  {
    name: 'search_customer',
    description: '顧客台帳から顧客を名前で検索する。カルテ・来店履歴・アレルギー・コース残回数を返す。',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: '顧客の名前（部分一致可）。例: 「山田」「田中美咲」' }
      },
      required: ['name']
    }
  },
  {
    name: 'get_menu_price',
    description: '施術メニューマスタから料金（税込）を取得する。会計計算に使用。',
    input_schema: {
      type: 'object',
      properties: {
        menu_name: { type: 'string', description: 'メニュー名（部分一致可）。例: 「フェイシャル」「脱毛」' }
      },
      required: ['menu_name']
    }
  },
  {
    name: 'get_sales_report',
    description: '予約台帳から売上レポートを集計する。今日・今週・今月の売上・来店件数・平均単価を返す。',
    input_schema: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['today', 'week', 'month'], description: '集計期間' }
      },
      required: ['period']
    }
  },
  {
    name: 'get_followup_list',
    description: '顧客台帳から指定日数以上来店がない要フォロー顧客を返す。',
    input_schema: {
      type: 'object',
      properties: {
        days: { type: 'number', description: '何日以上来店なし（デフォルト90）' }
      }
    }
  },
  {
    name: 'add_activity_log',
    description: '活動ログに記録を追加する。来店・会計・連絡などの履歴を残す。確認後に呼び出すこと。',
    input_schema: {
      type: 'object',
      properties: {
        customer_name: { type: 'string', description: '対象顧客名' },
        type: { type: 'string', description: '種別（来店・会計完了・電話・LINE・予約確認など）' },
        content: { type: 'string', description: '内容の詳細' },
        result: { type: 'string', description: '結果（完了・予約確定・検討中など）' }
      },
      required: ['type', 'content']
    }
  }
];

function buildSystemPrompt(now = new Date()) {
  return `あなたは「みやびAIサロン」のスタッフサポートAIです。
合同会社みやびが運営する、エステサロン（浜松市）専用の業務アシスタントです。

## 役割
- スタッフが話しかけるだけで、予約・会計・顧客情報・売上確認がすべて完結する
- Lark Base（顧客台帳・予約台帳・施術メニュー・活動ログ）にアクセスして情報を取得・更新する
- 難しいシステム操作は不要。チャットで話しかけるだけで動く

## 行動原則
1. **確認ゲートを必ず挟む**: データを更新する操作（会計記録・予約登録）は「〜してよいですか？」と確認し、「はい」を受けてから実行
2. **顧客が曖昧な場合は絞り込む**: 「田中さん」で複数ヒットした場合は候補を提示
3. **アレルギーは必ず警告**: 顧客カルテにアレルギー情報がある場合は ⚠️ で表示
4. **短く的確に答える**: スタッフは施術中・移動中にチャットを見ている
5. **日本語・丁寧語（です・ます）**: 過剰な敬語は使わない

## できること
- 予約照会（当日・翌日・指定日）
- 顧客カルテ検索（名前・ランク・来店履歴・アレルギー・施術メモ）
- 会計計算（メニューから税込料金を自動計算）
- 売上レポート（今日・今週・今月）
- 失客アラート（最終来店から90日以上）
- 活動ログの記録

## できないこと（必ず正直に伝える）
- 実際の決済処理（金額計算と記録のみ）
- メニュー価格の変更（管理者が直接 Lark Base で変更）
- LINEメッセージの実際の送信（文案生成まで）
- 医療・美容の専門的アドバイス

今日の日付: ${now.toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short' })}`;
}

function createAnthropicClient(env = process.env) {
  const rawBase = env.ZAI_API_BASE || 'https://api.anthropic.com';
  const sdkBase = rawBase.replace(/\/v1\/?$/, '');

  return new Anthropic({
    apiKey: env.ZAI_API_KEY || env.ANTHROPIC_API_KEY || 'dummy',
    baseURL: sdkBase,
    defaultHeaders: {
      'anthropic-version': '2023-06-01'
    }
  });
}

function msToDateStr(ms) {
  if (!ms) return '';
  return new Date(ms).toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit' });
}

// YYYY/MM/DD string from a Date object (used for Lark date comparison)
function toYMD(d) {
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`;
}

// YYYY-MM string from a Date object
function toYM(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

// Extract the first value from Lark's array-or-scalar field format
function firstVal(field) {
  return Array.isArray(field) ? field[0] : field || '';
}

function isSameDay(ms, dateStr) {
  if (!ms) return false;
  const normalized = toYMD(new Date(ms));
  const [y, m, day] = normalized.split('/');
  return dateStr.replace(/-/g, '/') === normalized || dateStr === `${y}-${m}-${day}`;
}

function isSameMonth(ms, yyyyMM) {
  if (!ms) return false;
  return toYM(new Date(ms)) === yyyyMM;
}

function getLarkConfig(env = process.env) {
  return {
    apiBase: env.LARK_API_BASE || 'https://open.larksuite.com',
    appId: env.FEISHU_APP_ID || env.LARK_APP_ID || '',
    appSecret: env.FEISHU_APP_SECRET || env.LARK_APP_SECRET || ''
  };
}

function resetTokenCache() {
  tokenCache.value = null;
  tokenCache.expiresAt = 0;
}

async function getTenantAccessToken({ fetchImpl = global.fetch, env = process.env, logger = console } = {}) {
  const now = Date.now();
  if (tokenCache.value && now < tokenCache.expiresAt - TOKEN_SAFETY_WINDOW_MS) {
    return tokenCache.value;
  }

  const { apiBase, appId, appSecret } = getLarkConfig(env);
  if (!appId || !appSecret) {
    throw new Error('FEISHU_APP_ID / FEISHU_APP_SECRET が設定されていません');
  }

  const response = await fetchImpl(`${apiBase}/open-apis/auth/v3/tenant_access_token/internal`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ app_id: appId, app_secret: appSecret })
  });

  if (!response.ok) {
    throw new Error(`Lark auth HTTP ${response.status}`);
  }

  const payload = await response.json();
  if (payload.code !== 0 || !payload.tenant_access_token) {
    logger.error('[lark] auth error:', payload.msg || payload.code);
    throw new Error(payload.msg || 'Lark auth failed');
  }

  tokenCache.value = payload.tenant_access_token;
  tokenCache.expiresAt = now + (payload.expire || 7200) * 1000;
  return tokenCache.value;
}

async function larkApi(method, apiPath, { data, fetchImpl = global.fetch, env = process.env, logger = console } = {}) {
  const token = await getTenantAccessToken({ fetchImpl, env, logger });
  const { apiBase } = getLarkConfig(env);
  const response = await fetchImpl(`${apiBase}${apiPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=utf-8'
    },
    body: data ? JSON.stringify(data) : undefined
  });

  if (!response.ok) {
    throw new Error(`Lark API HTTP ${response.status}`);
  }

  const payload = await response.json();
  if (payload.code !== 0) {
    logger.warn('[lark] API error code:', payload.code, payload.msg);
    throw new Error(payload.msg || `Lark API error ${payload.code}`);
  }

  return payload.data ?? payload;
}

async function getRecords(tableId, pageSize = 100, deps = {}) {
  const allItems = [];
  let pageToken = '';
  do {
    const url = `/open-apis/bitable/v1/apps/${BASE_TOKEN}/tables/${tableId}/records?page_size=${pageSize}${pageToken ? `&page_token=${encodeURIComponent(pageToken)}` : ''}`;
    const data = await larkApi('GET', url, deps);
    (data.items ?? []).forEach((record) => allItems.push({ _id: record.record_id, ...record.fields }));
    pageToken = data.has_more ? (data.page_token ?? '') : '';
  } while (pageToken);
  return allItems;
}

async function getReservations({ date }, deps = {}) {
  try {
    const now = new Date();
    const targetDate = date || toYMD(now);

    const records = await getRecords(TBL_BOOKING, 100, deps);
    const filtered = records.filter((record) => isSameDay(record['予約日時'], targetDate));

    if (filtered.length === 0) {
      return { date: targetDate, count: 0, reservations: [], message: `${targetDate}の予約はありません` };
    }

    return {
      date: targetDate,
      count: filtered.length,
      reservations: filtered
        .map((record) => {
          const dt = record['予約日時'] ? new Date(record['予約日時']) : null;
          const timeStr = dt ? `${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}` : '';
          const menuField = record['施術メニュー'];
          const menuName = Array.isArray(menuField) ? menuField[0]?.text || '' : String(menuField || '');
          return {
            time: timeStr,
            customer: record['お客様のお名前'] || '(名前不明)',
            menu: menuName,
            price: record['税込合計'] ? `¥${Number(record['税込合計']).toLocaleString()}` : '',
            status: firstVal(record['ステータス']),
            note: record['カルテメモ'] || record['アレルギー・ご要望'] || ''
          };
        })
        .sort((a, b) => a.time.localeCompare(b.time))
    };
  } catch (error) {
    return { error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

async function searchCustomer({ name }, deps = {}) {
  try {
    const records = await getRecords(TBL_CUSTOMER, 100, deps);
    const matched = records.filter((record) => {
      const customerName = record['氏名'] || '';
      return customerName.includes(name);
    });

    if (matched.length === 0) {
      return {
        found: false,
        message: `「${name}」さんの顧客情報が見つかりませんでした。別の表記（ひらがな、漢字違いなど）で試してみてください。`
      };
    }

    return {
      found: true,
      count: matched.length,
      customers: matched.map((record) => ({
        name: record['氏名'] || '',
        rank: firstVal(record['顧客ランク']),
        visits: record['来店回数'] || 0,
        total_amount: record['累計購入金額'] ? `¥${Number(record['累計購入金額']).toLocaleString()}` : '¥0',
        last_visit: msToDateStr(record['最終来店日']),
        next_booking: msToDateStr(record['次回予約日']),
        allergy: record['アレルギー・特記事項'] || '',
        memo: record['スタッフメモ'] || '',
        course: record['検討中コース'] || '',
        status: firstVal(record['ステータス'])
      }))
    };
  } catch (error) {
    return { error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

async function getMenuPrice({ menu_name: menuName }, deps = {}) {
  try {
    const records = await getRecords(TBL_MENU, 50, deps);
    const matched = records.filter((record) => {
      const name = record['メニュー名'] || '';
      return name.includes(menuName);
    });

    const unique = matched.filter(
      (record, index) => matched.findIndex((candidate) => candidate['メニュー名'] === record['メニュー名']) === index
    );

    if (unique.length === 0) {
      return { found: false, message: `「${menuName}」はメニューに見つかりませんでした` };
    }

    return {
      found: true,
      menus: unique.map((record) => ({
        name: record['メニュー名'] || '',
        category: record['カテゴリ'] || '',
        price: record['料金_税込'] ? `¥${Number(record['料金_税込']).toLocaleString()}（税込）` : '',
        minutes: record['所要時間_分'] ? `${record['所要時間_分']}分` : ''
      }))
    };
  } catch (error) {
    return { error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

async function getSalesReport({ period }, deps = {}) {
  try {
    const records = await getRecords(TBL_BOOKING, 500, deps);
    const now = new Date();
    let target = [];
    let label = '';

    if (period === 'today') {
      target = records.filter((record) => isSameDay(record['予約日時'], toYMD(now)));
      label = '本日';
    } else if (period === 'month') {
      target = records.filter((record) => isSameMonth(record['予約日時'], toYM(now)));
      label = `${now.getMonth() + 1}月（${now.getFullYear()}年）`;
    } else if (period === 'week') {
      const weekAgoMs = now.getTime() - 7 * 24 * 60 * 60 * 1000;
      target = records.filter((record) => record['予約日時'] && record['予約日時'] >= weekAgoMs);
      label = '今週（7日間）';
    }

    const total = target
      .map((record) => {
        const value = record['税込合計'];
        return typeof value === 'number' ? value : parseInt(String(value || '0').replace(/[^0-9]/g, ''), 10) || 0;
      })
      .reduce((sum, amount) => sum + amount, 0);

    return {
      period: label,
      count: target.length,
      total_amount: total,
      formatted: `¥${total.toLocaleString()}`,
      avg_per_visit: target.length > 0 ? Math.round(total / target.length) : 0
    };
  } catch (error) {
    return { error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

async function getFollowupList({ days = 90 }, deps = {}) {
  try {
    const records = await getRecords(TBL_CUSTOMER, 100, deps);
    const now = Date.now();
    const threshold = days * 24 * 60 * 60 * 1000;

    const followup = records
      .filter((record) => {
        const lastVisit = record['最終来店日'];
        return Boolean(lastVisit) && now - lastVisit >= threshold;
      })
      .map((record) => ({
        name: record['氏名'] || '',
        rank: firstVal(record['顧客ランク']),
        last_visit: msToDateStr(record['最終来店日']),
        days_ago: Math.floor((now - record['最終来店日']) / (24 * 60 * 60 * 1000))
      }))
      .sort((a, b) => b.days_ago - a.days_ago);

    return {
      threshold_days: days,
      count: followup.length,
      customers: followup
    };
  } catch (error) {
    return { error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

async function addActivityLog({ type, content, result }, deps = {}) {
  try {
    await larkApi(
      'POST',
      `/open-apis/bitable/v1/apps/${BASE_TOKEN}/tables/${TBL_LOG}/records`,
      {
        ...deps,
        data: {
          fields: {
            日時: Date.now(),
            種別: type || 'その他',
            内容: content || '',
            結果: result || '',
            担当スタッフ: 'AI アシスタント'
          }
        }
      }
    );

    return { success: true, message: `活動ログを記録しました（${type}）` };
  } catch (error) {
    return { success: false, error: `${LARK_ERROR_MESSAGE}: ${error.message}` };
  }
}

function hasToolError(result) {
  return Boolean(result && typeof result === 'object' && result.error);
}

function renderDataUnavailable(errorMessages) {
  const items = errorMessages.map((message) => `<li>${message}</li>`).join('');
  return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ROI ダッシュボード — データ取得エラー</title>
<style>
body{font-family:'DM Sans','Noto Sans JP',sans-serif;background:#141210;color:#F5F2ED;padding:32px}
.card{max-width:720px;margin:0 auto;background:#1E1B18;border:1px solid rgba(245,242,237,.08);border-radius:16px;padding:24px}
h1{font-size:1.5rem;margin-bottom:12px}
p{color:rgba(245,242,237,.72);line-height:1.7}
ul{margin:16px 0 0 20px;color:#D8C4A1;line-height:1.8}
</style>
</head>
<body>
  <div class="card">
    <h1>ライブデータを取得できませんでした</h1>
    <p>Lark Base との接続に失敗したため、空データではなくエラーとして表示しています。認証情報と Lark API の疎通を確認してください。</p>
    <ul>${items}</ul>
  </div>
</body>
</html>`;
}

async function executeTool(name, input, toolImpls) {
  switch (name) {
    case 'get_reservations':
      return toolImpls.get_reservations(input);
    case 'search_customer':
      return toolImpls.search_customer(input);
    case 'get_menu_price':
      return toolImpls.get_menu_price(input);
    case 'get_sales_report':
      return toolImpls.get_sales_report(input);
    case 'get_followup_list':
      return toolImpls.get_followup_list(input);
    case 'add_activity_log':
      return toolImpls.add_activity_log(input);
    default:
      return { error: `未知のツール: ${name}` };
  }
}

function createDefaultToolImpls(deps = {}) {
  return {
    get_reservations: (input) => getReservations(input, deps),
    search_customer: (input) => searchCustomer(input, deps),
    get_menu_price: (input) => getMenuPrice(input, deps),
    get_sales_report: (input) => getSalesReport(input, deps),
    get_followup_list: (input) => getFollowupList(input, deps),
    add_activity_log: (input) => addActivityLog(input, deps)
  };
}

function createApp({ anthropicClient = createAnthropicClient(), toolImpls = createDefaultToolImpls(), logger = console } = {}) {
  const app = express();
  app.use(express.json());

  app.use((req, res, next) => {
    if (req.path.startsWith('/embed')) {
      res.setHeader('X-Frame-Options', 'ALLOWALL');
      res.setHeader('Content-Security-Policy', 'frame-ancestors *');
      res.setHeader('Access-Control-Allow-Origin', '*');
    }
    next();
  });

  app.use(express.static(path.join(__dirname, 'public')));

  app.post('/api/chat', async (req, res) => {
    const { message, history = [] } = req.body;
    if (!message) {
      return res.status(400).json({ error: 'message is required' });
    }

    logger.log(`[chat] "${message}"`);

    const messages = [
      ...history.map((item) => ({ role: item.role, content: item.content })),
      { role: 'user', content: message }
    ];

    try {
      let response;
      for (let i = 0; i < 5; i += 1) {
        response = await anthropicClient.messages.create({
          model: process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-6',
          max_tokens: 1024,
          system: buildSystemPrompt(),
          tools: TOOLS,
          messages
        });

        if (response.stop_reason === 'end_turn') {
          break;
        }

        if (response.stop_reason === 'tool_use') {
          messages.push({ role: 'assistant', content: response.content });

          const toolResults = await Promise.all(
            response.content
              .filter((block) => block.type === 'tool_use')
              .map(async (block) => ({
                type: 'tool_result',
                tool_use_id: block.id,
                content: JSON.stringify(await executeTool(block.name, block.input, toolImpls))
              }))
          );

          messages.push({ role: 'user', content: toolResults });
          continue;
        }

        break;
      }

      const reply = response.content
        .filter((block) => block.type === 'text')
        .map((block) => block.text)
        .join('');

      return res.json({ reply, usage: response.usage });
    } catch (error) {
      logger.error('[chat] error:', error.message);
      return res.status(500).json({ error: error.message });
    }
  });

  app.get('/embed/roi', async (req, res) => {
    const monthSales = await toolImpls.get_sales_report({ period: 'month' });
    const todaySales = await toolImpls.get_sales_report({ period: 'today' });
    const followup = await toolImpls.get_followup_list({ days: 60 });

    const errors = [monthSales, todaySales, followup].filter(hasToolError).map((item) => item.error);
    if (errors.length > 0) {
      res.status(503).setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.send(renderDataUnavailable(errors));
    }

    const monthTotal = monthSales.total_amount || 0;
    const monthCount = monthSales.count || 0;
    const avgVisit = monthSales.avg_per_visit || 0;
    const todayCount = todaySales.count || 0;
    const lostCount = followup.count || 0;

    const MY_INITIAL = 198000;
    const MY_MONTHLY = 22000;
    const MY_3Y = MY_INITIAL + MY_MONTHLY * 36;
    const POS_INITIAL = 165000;
    const POS_MONTHLY = 30000;
    const POS_3Y = POS_INITIAL + POS_MONTHLY * 36;
    const SAVINGS_3Y = POS_3Y - MY_3Y;

    const now = new Date();
    const dateStr = now.toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit' });

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(`<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ROI ダッシュボード — みやびAIサロン</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@300;400&family=DM+Sans:wght@400;500&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#141210;color:#F5F2ED;font-family:'DM Sans','Noto Sans JP',sans-serif;padding:32px;min-height:100vh}
.header{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:40px;padding-bottom:20px;border-bottom:1px solid rgba(245,242,237,0.08)}
.title{font-family:'Cormorant Garamond',serif;font-size:1.8rem;font-weight:400;color:#F5F2ED}
.subtitle{font-size:0.75rem;color:rgba(245,242,237,0.45);letter-spacing:.08em;text-transform:uppercase;margin-top:4px}
.date{font-size:0.75rem;color:rgba(245,242,237,0.35)}
.kpi-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:32px}
.kpi{background:#1E1B18;border:1px solid rgba(245,242,237,0.06);border-radius:12px;padding:24px}
.kpi-label{font-size:0.7rem;letter-spacing:.1em;text-transform:uppercase;color:rgba(245,242,237,0.45);margin-bottom:8px}
.kpi-value{font-family:'Cormorant Garamond',serif;font-size:2.2rem;font-weight:400;color:#C4A97A;line-height:1}
.kpi-unit{font-size:0.75rem;color:rgba(245,242,237,0.45);margin-top:6px}
.section-title{font-size:0.7rem;letter-spacing:.12em;text-transform:uppercase;color:rgba(245,242,237,0.35);margin-bottom:16px}
.compare-row{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:32px}
.plan{background:#1E1B18;border:1px solid rgba(245,242,237,0.06);border-radius:12px;padding:24px}
.plan.highlight{border-color:rgba(150,123,82,0.35);background:#201D1A}
.plan-badge{font-size:0.65rem;letter-spacing:.1em;text-transform:uppercase;color:#967B52;background:rgba(150,123,82,0.12);display:inline-block;padding:3px 10px;border-radius:99px;margin-bottom:12px}
.plan-name{font-family:'Cormorant Garamond',serif;font-size:1.3rem;color:#F5F2ED;margin-bottom:16px}
.plan-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(245,242,237,0.05);font-size:0.8rem}
.plan-row:last-child{border:none}
.plan-row-label{color:rgba(245,242,237,0.5)}
.plan-row-value{color:#F5F2ED;font-weight:500}
.plan-total{display:flex;justify-content:space-between;margin-top:16px;padding-top:16px;border-top:1px solid rgba(245,242,237,0.12)}
.plan-total-label{font-size:0.75rem;color:rgba(245,242,237,0.5);text-transform:uppercase;letter-spacing:.06em}
.plan-total-value{font-family:'Cormorant Garamond',serif;font-size:1.6rem;color:#C4A97A}
.savings-bar{background:#1E1B18;border:1px solid rgba(150,123,82,0.25);border-radius:12px;padding:24px;text-align:center}
.savings-amount{font-family:'Cormorant Garamond',serif;font-size:2.8rem;color:#C4A97A}
.savings-label{font-size:0.8rem;color:rgba(245,242,237,0.5);margin-top:4px}
.live-tag{font-size:0.6rem;color:#967B52;background:rgba(150,123,82,0.12);padding:2px 8px;border-radius:99px;margin-left:8px;vertical-align:middle}
</style>
</head>
<body>
<div class="header">
  <div>
    <div class="title">ROI ダッシュボード<span class="live-tag">LIVE</span></div>
    <div class="subtitle">みやびAIサロン — 費用対効果レポート</div>
  </div>
  <div class="date">${dateStr} 現在</div>
</div>

<div class="section-title">リアルタイム 運用データ</div>
<div class="kpi-grid">
  <div class="kpi">
    <div class="kpi-label">今月売上</div>
    <div class="kpi-value">¥${monthTotal.toLocaleString()}</div>
    <div class="kpi-unit">${monthCount}件 / 平均 ¥${avgVisit.toLocaleString()}</div>
  </div>
  <div class="kpi">
    <div class="kpi-label">本日の予約</div>
    <div class="kpi-value">${todayCount}</div>
    <div class="kpi-unit">件</div>
  </div>
  <div class="kpi">
    <div class="kpi-label">要フォロー顧客</div>
    <div class="kpi-value">${lostCount}</div>
    <div class="kpi-unit">60日以上未来店</div>
  </div>
</div>

<div class="section-title">3年間 TCO 比較</div>
<div class="compare-row">
  <div class="plan">
    <div class="plan-badge">競合</div>
    <div class="plan-name">Power Knowledge POS</div>
    <div class="plan-row"><span class="plan-row-label">初期費用</span><span class="plan-row-value">¥165,000</span></div>
    <div class="plan-row"><span class="plan-row-label">月額</span><span class="plan-row-value">¥30,000/月</span></div>
    <div class="plan-row"><span class="plan-row-label">AI機能</span><span class="plan-row-value">なし</span></div>
    <div class="plan-total">
      <span class="plan-total-label">3年合計</span>
      <span class="plan-total-value">¥${POS_3Y.toLocaleString()}</span>
    </div>
  </div>
  <div class="plan highlight">
    <div class="plan-badge">みやび提案</div>
    <div class="plan-name">みやびAI + Lark Base</div>
    <div class="plan-row"><span class="plan-row-label">初期費用</span><span class="plan-row-value">¥198,000</span></div>
    <div class="plan-row"><span class="plan-row-label">月額</span><span class="plan-row-value">¥22,000/月</span></div>
    <div class="plan-row"><span class="plan-row-label">AI機能</span><span class="plan-row-value">Claude AI 搭載</span></div>
    <div class="plan-total">
      <span class="plan-total-label">3年合計</span>
      <span class="plan-total-value">¥${MY_3Y.toLocaleString()}</span>
    </div>
  </div>
</div>

<div class="savings-bar">
  <div class="savings-amount">¥${SAVINGS_3Y.toLocaleString()}</div>
  <div class="savings-label">3年間の削減コスト（競合比）</div>
</div>
</body>
</html>`);
  });

  app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'chat.html'));
  });

  app.get('/lp', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
  });

  return app;
}

function startServer(app, port = process.env.PORT || 3000, logger = console) {
  return app.listen(port, () => {
    logger.log(`
╔════════════════════════════════════════════╗
║   みやびAIサロン MVP サーバー              ║
║   http://localhost:${port}                    ║
╚════════════════════════════════════════════╝

  チャット:  http://localhost:${port}/
  LP:        http://localhost:${port}/lp
  API:       POST http://localhost:${port}/api/chat
`);
  });
}

const app = createApp();

if (require.main === module) {
  startServer(app);
}

// Export the Express app as the module default so Vercel's @vercel/node runtime
// can use it as a request handler. Named exports remain accessible for tests.
module.exports = app;
Object.assign(module.exports, {
  app,
  TOOLS,
  addActivityLog,
  buildSystemPrompt,
  createAnthropicClient,
  createApp,
  createDefaultToolImpls,
  getFollowupList,
  getMenuPrice,
  getRecords,
  getReservations,
  getSalesReport,
  getTenantAccessToken,
  hasToolError,
  larkApi,
  resetTokenCache,
  renderDataUnavailable,
  searchCustomer,
  startServer
});
