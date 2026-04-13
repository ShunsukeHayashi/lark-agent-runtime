/**
 * Enhanced Token Manager with Security Features
 *
 * This module provides secure token management with encryption, rotation,
 * and automatic refresh capabilities for the Lark OpenAPI MCP integration.
 */

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { EventEmitter } from 'events';

export interface TokenConfig {
  appId: string;
  appSecret: string;
  userAccessToken?: string;
  encryptionKey?: string;
  refreshInterval?: number; // in minutes
  tokenExpiry?: number; // in seconds
}

export interface SecureTokenStorage {
  encryptedTokens: string;
  tokenHash: string;
  lastRotation: string;
  expiresAt: string;
  version: string;
}

export interface TokenRotationConfig {
  enabled: boolean;
  rotationInterval: number; // in minutes
  maxTokenAge: number; // in hours
  backupCount: number;
}

export class SecureTokenManager extends EventEmitter {
  private config: TokenConfig;
  private rotationConfig: TokenRotationConfig;
  private credentialsPath: string;
  private encryptionKey: Buffer;
  private rotationTimer?: NodeJS.Timeout;
  private currentTokens: Map<string, { value: string; expiresAt: Date }>;

  constructor(config: TokenConfig, rotationConfig?: Partial<TokenRotationConfig>) {
    super();
    this.config = config;
    this.rotationConfig = {
      enabled: true,
      rotationInterval: 90, // 90 minutes
      maxTokenAge: 24, // 24 hours
      backupCount: 5,
      ...rotationConfig,
    };

    this.credentialsPath = path.join(
      process.env.HOME || process.env.USERPROFILE || '.',
      '.lark-mcp',
      'secure-credentials.json',
    );
    this.currentTokens = new Map();

    // Initialize encryption key
    this.encryptionKey = this.deriveEncryptionKey();

    // Load existing tokens
    this.loadTokens();

    // Start automatic token rotation
    if (this.rotationConfig.enabled) {
      this.startTokenRotation();
    }
  }

  /**
   * Derive encryption key from app secret and system entropy
   */
  private deriveEncryptionKey(): Buffer {
    const salt = crypto.randomBytes(32);
    const baseKey = this.config.encryptionKey || this.config.appSecret;

    // Use PBKDF2 for key derivation
    return crypto.pbkdf2Sync(baseKey, salt, 100000, 32, 'sha256');
  }

  /**
   * Encrypt sensitive data using AES-256-GCM
   */
  private encrypt(data: string): { encrypted: string; iv: string; tag: string } {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher('aes-256-gcm', this.encryptionKey);
    cipher.setAAD(Buffer.from(this.config.appId)); // Additional authenticated data

    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    const tag = cipher.getAuthTag();

    return {
      encrypted,
      iv: iv.toString('hex'),
      tag: tag.toString('hex'),
    };
  }

  /**
   * Decrypt sensitive data
   */
  private decrypt(encryptedData: { encrypted: string; iv: string; tag: string }): string {
    const decipher = crypto.createDecipher('aes-256-gcm', this.encryptionKey);
    decipher.setAAD(Buffer.from(this.config.appId));
    decipher.setAuthTag(Buffer.from(encryptedData.tag, 'hex'));

    let decrypted = decipher.update(encryptedData.encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  }

  /**
   * Generate secure hash for token validation
   */
  private generateTokenHash(token: string): string {
    return crypto
      .createHash('sha256')
      .update(token + this.config.appId)
      .digest('hex');
  }

  /**
   * Validate token integrity
   */
  private validateTokenHash(token: string, hash: string): boolean {
    return this.generateTokenHash(token) === hash;
  }

  /**
   * Store tokens securely with encryption
   */
  async storeTokens(tokens: { [key: string]: string }): Promise<void> {
    const tokensData = JSON.stringify(tokens);
    const encryptedData = this.encrypt(tokensData);

    const secureStorage: SecureTokenStorage = {
      encryptedTokens: JSON.stringify(encryptedData),
      tokenHash: this.generateTokenHash(tokensData),
      lastRotation: new Date().toISOString(),
      expiresAt: new Date(Date.now() + this.rotationConfig.maxTokenAge * 60 * 60 * 1000).toISOString(),
      version: '1.0',
    };

    // Ensure directory exists
    const dir = path.dirname(this.credentialsPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
    }

    // Write with secure permissions
    fs.writeFileSync(this.credentialsPath, JSON.stringify(secureStorage, null, 2), { mode: 0o600 });

    // Update in-memory cache
    for (const [key, value] of Object.entries(tokens)) {
      this.currentTokens.set(key, {
        value,
        expiresAt: new Date(Date.now() + (this.config.tokenExpiry || 7200) * 1000),
      });
    }

    this.emit('tokensStored', { keys: Object.keys(tokens), timestamp: new Date() });
  }

  /**
   * Load and decrypt tokens
   */
  private loadTokens(): void {
    try {
      if (!fs.existsSync(this.credentialsPath)) {
        return;
      }

      const fileContent = fs.readFileSync(this.credentialsPath, 'utf8');
      const secureStorage: SecureTokenStorage = JSON.parse(fileContent);

      // Check if tokens are expired
      if (new Date() > new Date(secureStorage.expiresAt)) {
        this.emit('tokensExpired', { expiredAt: secureStorage.expiresAt });
        return;
      }

      // Decrypt tokens
      const encryptedData = JSON.parse(secureStorage.encryptedTokens);
      const decryptedData = this.decrypt(encryptedData);

      // Validate integrity
      if (!this.validateTokenHash(decryptedData, secureStorage.tokenHash)) {
        throw new Error('Token integrity validation failed');
      }

      const tokens = JSON.parse(decryptedData);

      // Load into memory
      for (const [key, value] of Object.entries(tokens)) {
        this.currentTokens.set(key, {
          value: value as string,
          expiresAt: new Date(secureStorage.expiresAt),
        });
      }

      this.emit('tokensLoaded', { keys: Object.keys(tokens), timestamp: new Date() });
    } catch (error) {
      this.emit('tokenLoadError', { error: (error as Error).message, timestamp: new Date() });
    }
  }

  /**
   * Get token with automatic refresh
   */
  async getToken(tokenType: 'userAccessToken' | 'tenantAccessToken' = 'userAccessToken'): Promise<string | null> {
    const cachedToken = this.currentTokens.get(tokenType);

    if (cachedToken && new Date() < cachedToken.expiresAt) {
      return cachedToken.value;
    }

    // Token expired or not found, attempt refresh
    await this.refreshToken(tokenType);

    const refreshedToken = this.currentTokens.get(tokenType);
    return refreshedToken?.value || null;
  }

  /**
   * Refresh token using Lark API
   */
  async refreshToken(tokenType: 'userAccessToken' | 'tenantAccessToken'): Promise<void> {
    try {
      if (tokenType === 'tenantAccessToken') {
        // Refresh tenant access token
        const response = await fetch('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal/', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            app_id: this.config.appId,
            app_secret: this.config.appSecret,
          }),
        });

        const data = await response.json();

        if (data.code === 0) {
          await this.storeTokens({
            [tokenType]: data.tenant_access_token,
          });

          this.emit('tokenRefreshed', { tokenType, timestamp: new Date() });
        } else {
          throw new Error(`Token refresh failed: ${data.msg}`);
        }
      } else {
        // User access token refresh requires OAuth flow
        this.emit('userTokenRefreshRequired', { timestamp: new Date() });
      }
    } catch (error) {
      this.emit('tokenRefreshError', { tokenType, error: (error as Error).message, timestamp: new Date() });
    }
  }

  /**
   * Rotate tokens automatically
   */
  private async rotateTokens(): Promise<void> {
    try {
      await this.refreshToken('tenantAccessToken');

      // Create backup of current tokens
      await this.createTokenBackup();

      this.emit('tokensRotated', { timestamp: new Date() });
    } catch (error) {
      this.emit('tokenRotationError', { error: (error as Error).message, timestamp: new Date() });
    }
  }

  /**
   * Create backup of current tokens
   */
  private async createTokenBackup(): Promise<void> {
    const backupPath = `${this.credentialsPath}.backup.${Date.now()}`;

    if (fs.existsSync(this.credentialsPath)) {
      fs.copyFileSync(this.credentialsPath, backupPath);

      // Clean up old backups
      await this.cleanupOldBackups();
    }
  }

  /**
   * Clean up old backup files
   */
  private async cleanupOldBackups(): Promise<void> {
    const dir = path.dirname(this.credentialsPath);
    const files = fs.readdirSync(dir);

    const backupFiles = files
      .filter((file) => file.startsWith(path.basename(this.credentialsPath) + '.backup.'))
      .map((file) => ({
        name: file,
        path: path.join(dir, file),
        timestamp: parseInt(file.split('.').pop() || '0'),
      }))
      .sort((a, b) => b.timestamp - a.timestamp);

    // Keep only the specified number of backups
    const filesToDelete = backupFiles.slice(this.rotationConfig.backupCount);

    for (const file of filesToDelete) {
      fs.unlinkSync(file.path);
    }
  }

  /**
   * Start automatic token rotation
   */
  private startTokenRotation(): void {
    const intervalMs = this.rotationConfig.rotationInterval * 60 * 1000;

    this.rotationTimer = setInterval(() => {
      this.rotateTokens();
    }, intervalMs);

    this.emit('tokenRotationStarted', {
      interval: this.rotationConfig.rotationInterval,
      timestamp: new Date(),
    });
  }

  /**
   * Stop automatic token rotation
   */
  stopTokenRotation(): void {
    if (this.rotationTimer) {
      clearInterval(this.rotationTimer);
      this.rotationTimer = undefined;
      this.emit('tokenRotationStopped', { timestamp: new Date() });
    }
  }

  /**
   * Revoke all tokens and clear storage
   */
  async revokeAllTokens(): Promise<void> {
    try {
      // Clear in-memory tokens
      this.currentTokens.clear();

      // Remove secure storage file
      if (fs.existsSync(this.credentialsPath)) {
        fs.unlinkSync(this.credentialsPath);
      }

      // Stop rotation
      this.stopTokenRotation();

      this.emit('tokensRevoked', { timestamp: new Date() });
    } catch (error) {
      this.emit('tokenRevocationError', { error: (error as Error).message, timestamp: new Date() });
    }
  }

  /**
   * Get token usage statistics
   */
  getTokenStats(): {
    totalTokens: number;
    expiredTokens: number;
    validTokens: number;
    lastRotation: Date | null;
  } {
    const now = new Date();
    let expiredTokens = 0;
    let validTokens = 0;

    for (const [, tokenData] of this.currentTokens) {
      if (now > tokenData.expiresAt) {
        expiredTokens++;
      } else {
        validTokens++;
      }
    }

    return {
      totalTokens: this.currentTokens.size,
      expiredTokens,
      validTokens,
      lastRotation: fs.existsSync(this.credentialsPath) ? fs.statSync(this.credentialsPath).mtime : null,
    };
  }

  /**
   * Validate token security
   */
  validateTokenSecurity(): {
    isSecure: boolean;
    issues: string[];
    recommendations: string[];
  } {
    const issues: string[] = [];
    const recommendations: string[] = [];

    // Check file permissions
    if (fs.existsSync(this.credentialsPath)) {
      const stats = fs.statSync(this.credentialsPath);
      const mode = stats.mode & parseInt('777', 8);

      if (mode !== parseInt('600', 8)) {
        issues.push('Credentials file has overly permissive permissions');
        recommendations.push('Set file permissions to 600 (owner read/write only)');
      }
    }

    // Check encryption key strength
    if (!this.config.encryptionKey) {
      issues.push('No custom encryption key provided');
      recommendations.push('Provide a strong encryption key for enhanced security');
    }

    // Check token rotation settings
    if (!this.rotationConfig.enabled) {
      issues.push('Token rotation is disabled');
      recommendations.push('Enable automatic token rotation for better security');
    }

    return {
      isSecure: issues.length === 0,
      issues,
      recommendations,
    };
  }
}

export default SecureTokenManager;
