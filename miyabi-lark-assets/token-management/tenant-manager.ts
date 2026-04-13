/**
 * Miyabi Lark OS - Tenant Auth Manager
 *
 * Manages Lark Tenant Access Token with automatic refresh and caching.
 * Implements FR-TENANT-001: Tenant Access Token acquisition and management.
 */

import { createClient } from 'redis';

/**
 * Tenant Access Token Response from Lark API
 */
interface TenantTokenResponse {
  code: number;
  msg: string;
  tenant_access_token: string;
  expire: number; // Expiration time in seconds (typically 7200 = 2 hours)
}

/**
 * Tenant Auth Manager
 *
 * Features:
 * - Automatic token acquisition
 * - 1-hour Redis caching
 * - Automatic refresh before expiration
 * - Error handling with retry logic
 */
export class TenantAuthManager {
  private appId: string;
  private appSecret: string;
  private redisClient: ReturnType<typeof createClient> | null = null;
  private inMemoryCache: {
    token: string | null;
    expiry: Date | null;
  } = {
    token: null,
    expiry: null,
  };

  constructor(appId: string, appSecret: string) {
    this.appId = appId;
    this.appSecret = appSecret;
  }

  /**
   * Initialize Redis client (optional, fallback to in-memory cache)
   */
  async initRedis(redisUrl?: string): Promise<void> {
    try {
      this.redisClient = createClient({
        url: redisUrl || process.env['REDIS_URL'] || 'redis://localhost:6379',
      });

      await this.redisClient.connect();
      console.log('[TenantAuthManager] Redis connected');
    } catch (error) {
      console.warn('[TenantAuthManager] Redis connection failed, using in-memory cache:', error);
      this.redisClient = null;
    }
  }

  /**
   * Get Tenant Access Token (with caching)
   *
   * @returns Tenant access token (valid for 2 hours)
   */
  async getTenantAccessToken(): Promise<string> {
    // 1. Check cache (Redis or in-memory)
    const cachedToken = await this.getCachedToken();
    if (cachedToken) {
      console.log('[TenantAuthManager] Using cached token');
      return cachedToken;
    }

    // 2. Acquire new token from Lark API
    console.log('[TenantAuthManager] Acquiring new tenant access token...');
    const token = await this.acquireNewToken();

    // 3. Cache for 1 hour (token valid for 2 hours, refresh at 50%)
    await this.cacheToken(token, 60 * 60); // 1 hour = 3600 seconds

    console.log('[TenantAuthManager] ✅ Tenant access token acquired and cached');
    return token;
  }

  /**
   * Acquire new token from Lark API
   *
   * API: POST /open-apis/auth/v3/tenant_access_token/internal
   */
  private async acquireNewToken(retries = 3): Promise<string> {
    const url = 'https://open.larksuite.com/open-apis/auth/v3/tenant_access_token/internal';

    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            app_id: this.appId,
            app_secret: this.appSecret,
          }),
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = (await response.json()) as TenantTokenResponse;

        if (data.code !== 0) {
          throw new Error(`Lark API error: ${data.msg} (code: ${data.code})`);
        }

        return data.tenant_access_token;
      } catch (error) {
        console.error(
          `[TenantAuthManager] Token acquisition failed (attempt ${attempt}/${retries}):`,
          error
        );

        if (attempt === retries) {
          throw new Error(`Failed to acquire tenant access token after ${retries} attempts`);
        }

        // Exponential backoff: 1s, 2s, 4s
        const delay = Math.pow(2, attempt - 1) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }

    throw new Error('Unreachable code');
  }

  /**
   * Get cached token (Redis or in-memory)
   */
  private async getCachedToken(): Promise<string | null> {
    // Try Redis first
    if (this.redisClient) {
      try {
        const token = await this.redisClient.get('lark:tenant_access_token');
        if (token) return token;
      } catch (error) {
        console.warn('[TenantAuthManager] Redis get failed:', error);
      }
    }

    // Fallback to in-memory cache
    if (this.inMemoryCache.token && this.inMemoryCache.expiry) {
      if (this.inMemoryCache.expiry > new Date()) {
        return this.inMemoryCache.token;
      }
    }

    return null;
  }

  /**
   * Cache token (Redis or in-memory)
   */
  private async cacheToken(token: string, ttlSeconds: number): Promise<void> {
    const expiry = new Date(Date.now() + ttlSeconds * 1000);

    // Try Redis first
    if (this.redisClient) {
      try {
        await this.redisClient.setEx('lark:tenant_access_token', ttlSeconds, token);
        console.log(`[TenantAuthManager] Token cached in Redis (TTL: ${ttlSeconds}s)`);
      } catch (error) {
        console.warn('[TenantAuthManager] Redis set failed:', error);
      }
    }

    // Always update in-memory cache (fallback)
    this.inMemoryCache.token = token;
    this.inMemoryCache.expiry = expiry;
    console.log(`[TenantAuthManager] Token cached in memory (expires: ${expiry.toISOString()})`);
  }

  /**
   * Force refresh token (useful for testing or manual refresh)
   */
  async refreshToken(): Promise<string> {
    // Clear cache
    if (this.redisClient) {
      try {
        await this.redisClient.del('lark:tenant_access_token');
      } catch (error) {
        console.warn('[TenantAuthManager] Redis delete failed:', error);
      }
    }

    this.inMemoryCache.token = null;
    this.inMemoryCache.expiry = null;

    console.log('[TenantAuthManager] Cache cleared, forcing token refresh');
    return this.getTenantAccessToken();
  }

  /**
   * Cleanup resources
   */
  async cleanup(): Promise<void> {
    if (this.redisClient) {
      await this.redisClient.quit();
      console.log('[TenantAuthManager] Redis connection closed');
    }
  }
}

/**
 * Singleton instance (recommended usage)
 */
let tenantAuthManagerInstance: TenantAuthManager | null = null;

export function getTenantAuthManager(): TenantAuthManager {
  if (!tenantAuthManagerInstance) {
    const appId = process.env['LARK_APP_ID'];
    const appSecret = process.env['LARK_APP_SECRET'];

    if (!appId || !appSecret) {
      throw new Error('LARK_APP_ID and LARK_APP_SECRET must be set in environment variables');
    }

    tenantAuthManagerInstance = new TenantAuthManager(appId, appSecret);
  }

  return tenantAuthManagerInstance;
}
