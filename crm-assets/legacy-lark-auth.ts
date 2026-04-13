import 'dotenv/config'

const LARK_API = 'https://open.larksuite.com/open-apis'

// ── Tenant token in-process cache ─────────────────────────────────────────
// Replaces the n8n lark-token-refresh workflow.
// The token is fetched on first use and refreshed every 90 minutes automatically.

let _tenantToken = ''
let _refreshTimer: ReturnType<typeof setInterval> | null = null

const REFRESH_INTERVAL_MS = 90 * 60 * 1000 // 90 min (token expires in 2h)

async function fetchTenantToken(): Promise<string> {
  const res = await fetch(`${LARK_API}/auth/v3/app_access_token/internal`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      app_id: process.env['LARK_APP_ID'],
      app_secret: process.env['LARK_APP_SECRET'],
    }),
  })
  const data = (await res.json()) as { code: number; tenant_access_token?: string; msg?: string }
  if (data.code !== 0 || !data.tenant_access_token) {
    throw new Error(`getTenantToken failed: ${data.msg ?? JSON.stringify(data)}`)
  }
  return data.tenant_access_token
}

/**
 * Start the background token refresh loop.
 * Call once at server startup; subsequent calls are no-ops.
 */
export async function startTokenRefresh(): Promise<void> {
  if (_refreshTimer) return
  _tenantToken = await fetchTenantToken()
  process.stdout.write('[auth] tenant_access_token acquired\n')

  _refreshTimer = setInterval(async () => {
    try {
      _tenantToken = await fetchTenantToken()
      process.stdout.write('[auth] tenant_access_token refreshed\n')
    } catch (err) {
      process.stderr.write(`[auth] token refresh failed: ${err}\n`)
    }
  }, REFRESH_INTERVAL_MS)

  // Don't block process exit
  _refreshTimer.unref()
}

/**
 * Get the current tenant_access_token.
 * Fetches on first call if startTokenRefresh() was not called (e.g. in CLI commands).
 */
export async function getTenantToken(): Promise<string> {
  if (!_tenantToken) _tenantToken = await fetchTenantToken()
  return _tenantToken
}

// ── User token ────────────────────────────────────────────────────────────

/**
 * Get a user_access_token for the given open_id.
 * Single-user: set LARK_USER_TOKEN env var.
 * Multi-user: set LARK_REFRESH_TOKEN_<open_id> env var, or implement a token store.
 */
export async function getUserToken(openId: string): Promise<string> {
  const envToken = process.env['LARK_USER_TOKEN']
  if (envToken) return envToken

  const refreshToken = process.env[`LARK_REFRESH_TOKEN_${openId}`]
  if (!refreshToken) {
    throw new Error(
      `No user_access_token for open_id=${openId}. Set LARK_USER_TOKEN or LARK_REFRESH_TOKEN_${openId}.`
    )
  }

  const res = await fetch(`${LARK_API}/auth/v3/oidc/refresh_access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      app_id: process.env['LARK_APP_ID'],
      app_secret: process.env['LARK_APP_SECRET'],
    }),
  })
  const data = (await res.json()) as { code: number; access_token?: string; msg?: string }
  if (data.code !== 0 || !data.access_token) {
    throw new Error(`getUserToken refresh failed for ${openId}: ${data.msg ?? JSON.stringify(data)}`)
  }
  return data.access_token
}
