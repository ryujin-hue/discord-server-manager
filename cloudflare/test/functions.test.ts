/**
 * Tests for the Cloudflare Functions library.
 *
 * These tests use an in-memory mock D1 to verify repository and helper logic
 * without a real Cloudflare account. They are NOT integration tests — they
 * verify the ported logic is correct given a D1-compatible interface.
 */

import { describe, expect, it } from 'vitest';
import { defaultGuildSettings, SettingsRepository, type GuildSettings } from '../../functions/_lib/db';
import { ok, failure, errorResponse } from '../../functions/_lib/http';
import { AppError } from '../../functions/_lib/errors';
import { MOBILE_CALLBACK, CALLBACK_ALLOWED_PARAMS, AuthStateStore } from '../../functions/_lib/auth';

/* -------------------------------------------------------------------------- */
/* Mock D1                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * A minimal in-memory D1 mock. Stores rows in a Map keyed by table name.
 * Supports prepare().bind().first/run/all and basic WHERE clause matching.
 */
class MockD1 {
  private tables = new Map<string, Map<string, Record<string, unknown>>>();
  private lastInsertRowId = 0;

  prepare(sql: string): MockStatement {
    return new MockStatement(this, sql);
  }

  getTable(name: string): Map<string, Record<string, unknown>> {
    if (!this.tables.has(name)) {
      this.tables.set(name, new Map());
    }
    return this.tables.get(name)!;
  }

  nextId(): number {
    this.lastInsertRowId += 1;
    return this.lastInsertRowId;
  }
}

class MockStatement {
  private params: unknown[] = [];

  constructor(private readonly db: MockD1, private readonly sql: string) {}

  bind(...params: unknown[]): this {
    this.params = params;
    return this;
  }

  async first<T = Record<string, unknown>>(): Promise<T | null> {
    const rows = this.execute();
    return (rows[0] as T) ?? null;
  }

  async all(): Promise<{ results: Record<string, unknown>[] }> {
    return { results: this.execute() };
  }

  async run(): Promise<{ meta: { changes: number; last_row_id: number } }> {
    const sql = this.sql.trim();

    // INSERT
    if (/^INSERT/i.test(sql)) {
      const table = this.extractTableName(sql);
      const map = this.db.getTable(table);
      const id = this.db.nextId();
      const row: Record<string, unknown> = {};
      // Simple: map positional params to column names parsed from SQL
      // This is enough for the tests below which use known schemas.
      if (table === 'guild_settings') {
        row['guild_id'] = this.params[0];
        row['payload'] = this.params[1];
        row['updated_at'] = this.params[2];
        map.set(String(this.params[0]), row);
      } else if (table === 'warnings') {
        row['id'] = id;
        row['guild_id'] = this.params[0];
        row['user_id'] = this.params[1];
        row['reason'] = this.params[2];
        row['warned_by'] = this.params[3];
        row['created_at'] = this.params[4];
        map.set(String(id), row);
      } else if (table === 'auth_states') {
        row['state_hash'] = this.params[0];
        row['created_at'] = this.params[1];
        row['expires_at'] = this.params[2];
        row['consumed_at'] = null;
        map.set(String(this.params[0]), row);
      } else if (table === 'cron_state') {
        row['key'] = this.params[0];
        row['value'] = this.params[1];
        row['updated_at'] = this.params[2];
        map.set(String(this.params[0]), row);
      } else {
        row['id'] = id;
        map.set(String(id), row);
      }
      return { meta: { changes: 1, last_row_id: id } };
    }

    // UPDATE
    if (/^UPDATE/i.test(sql)) {
      const table = this.extractTableName(sql);
      const map = this.db.getTable(table);
      let changes = 0;
      for (const [, row] of map) {
        if (this.matchesUpdateWhere(row, sql)) {
          if (sql.includes('consumed_at = ?')) {
            row['consumed_at'] = this.params[0];
            changes += 1;
          }
        }
      }
      return { meta: { changes, last_row_id: 0 } };
    }

    return { meta: { changes: 0, last_row_id: 0 } };
  }

  private execute(): Record<string, unknown>[] {
    const sql = this.sql.trim();

    if (/^SELECT/i.test(sql)) {
      const table = this.extractTableName(sql);
      const map = this.db.getTable(table);
      const rows: Record<string, unknown>[] = [];
      for (const [, row] of map) {
        if (this.matchesWhere(row, sql)) {
          rows.push({ ...row });
        }
      }
      // Handle LIMIT
      const limitMatch = /LIMIT\s+(\?|\d+)/i.exec(sql);
      if (limitMatch) {
        const limitVal = limitMatch[1] === '?' ? Number(this.params[this.params.length - 1]) : Number(limitMatch[1]);
        return rows.slice(0, limitVal);
      }
      return rows;
    }

    return [];
  }

  private extractTableName(sql: string): string {
    const match = /(?:FROM|INTO|UPDATE)\s+(\w+)/i.exec(sql);
    return match?.[1] ?? 'unknown';
  }

  private matchesWhere(row: Record<string, unknown>, sql: string): boolean {
    const whereMatch = /WHERE\s+(\w+)\s*=\s*\?/i.exec(sql);
    if (!whereMatch) return true;
    const column = whereMatch[1];
    const paramIndex = this.indexOfBind(column, sql);
    const expected = this.params[paramIndex];
    return String(row[column]) === String(expected);
  }

  /**
   * Handles the UPDATE WHERE clause shape used by AuthStateStore.consume:
   *   WHERE state_hash = ? AND consumed_at IS NULL AND expires_at >= ?
   * The bind params for UPDATE SET ... WHERE are: [set_value, ...where_values]
   */
  private matchesUpdateWhere(row: Record<string, unknown>, sql: string): boolean {
    const whereIdx = sql.toUpperCase().indexOf('WHERE');
    if (whereIdx === -1) return true;
    const clause = sql.slice(whereIdx);

    // state_hash = ? (first WHERE bind param after the SET value)
    const hashMatch = /state_hash\s*=\s*\?/i.exec(clause);
    if (hashMatch) {
      const whereParamOffset = 1; // params[0] is the SET value (consumed_at)
      if (String(row['state_hash']) !== String(this.params[whereParamOffset])) return false;
    }

    // consumed_at IS NULL
    if (/consumed_at\s+IS\s+NULL/i.test(clause)) {
      if (row['consumed_at'] !== null && row['consumed_at'] !== undefined) return false;
    }

    // expires_at >= ? (second WHERE bind param)
    const expiresMatch = /expires_at\s*>=\s*\?/i.exec(clause);
    if (expiresMatch) {
      const expiresParamOffset = 2; // params[0]=SET, params[1]=state_hash, params[2]=expires_at
      const threshold = Number(this.params[expiresParamOffset]);
      if (Number(row['expires_at']) < threshold) return false;
    }

    return true;
  }

  private indexOfBind(column: string, sql: string): number {
    // Count ? placeholders before the WHERE clause for this column
    const whereIdx = sql.toUpperCase().indexOf('WHERE');
    const before = sql.slice(0, whereIdx);
    const count = (before.match(/\?/g) ?? []).length;
    // The WHERE column is the next ? after 'before'
    const afterClause = sql.slice(whereIdx);
    const match = new RegExp(`${column}\\s*=\\s*\\?`, 'i').exec(afterClause);
    if (!match) return 0;
    const beforeCol = afterClause.slice(0, match.index!);
    const countAfter = (beforeCol.match(/\?/g) ?? []).length;
    return count + countAfter;
  }
}

/* -------------------------------------------------------------------------- */
/* Tests                                                                      */
/* -------------------------------------------------------------------------- */

describe('http helpers', () => {
  it('ok wraps data in { data: ... }', async () => {
    const response = ok({ hello: 'world' });
    expect(response.status).toBe(200);
    const body = JSON.parse(await response.text()) as { data: unknown };
    expect(body.data).toEqual({ hello: 'world' });
  });

  it('failure wraps error in { error: { code, message } }', async () => {
    const response = failure({ code: 'not_found', message: 'missing' }, 404);
    expect(response.status).toBe(404);
    const body = JSON.parse(await response.text()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('not_found');
    expect(body.error.message).toBe('missing');
  });

  it('errorResponse maps AppError to the right status and code', async () => {
    const error = AppError.unauthorized('bad token');
    const response = errorResponse(error);
    expect(response.status).toBe(401);
    const body = JSON.parse(await response.text()) as { error: { code: string } };
    expect(body.error.code).toBe('unauthorized');
  });

  it('errorResponse maps unknown errors to internal_error', async () => {
    const response = errorResponse(new Error('boom'));
    expect(response.status).toBe(500);
    const body = JSON.parse(await response.text()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('internal_error');
    expect(body.error.message).not.toContain('boom');
  });
});

describe('auth constants', () => {
  it('MOBILE_CALLBACK is the fixed custom scheme', () => {
    expect(MOBILE_CALLBACK).toBe('my-discord-manager://oauth2/callback');
  });

  it('CALLBACK_ALLOWED_PARAMS only contains code, state, error, error_description', () => {
    expect([...CALLBACK_ALLOWED_PARAMS]).toEqual(['code', 'state', 'error', 'error_description']);
  });
});

describe('AuthStateStore', () => {
  it('consume returns false for an unknown state', async () => {
    const db = new MockD1() as unknown as D1Database;
    const store = new AuthStateStore(db);
    const consumed = await store.consume('nonexistent-state-1234567890');
    expect(consumed).toBe(false);
  });

  it('issue then consume returns true (single-use)', async () => {
    const db = new MockD1() as unknown as D1Database;
    const store = new AuthStateStore(db);
    const state = 'test-state-for-issue-consume-flow-abc';
    await store.issue(state);
    const first = await store.consume(state);
    expect(first).toBe(true);
    // Second consumption should fail (already consumed)
    const second = await store.consume(state);
    expect(second).toBe(false);
  });
});

describe('SettingsRepository', () => {
  it('returns defaults for a guild with no stored settings', async () => {
    const db = new MockD1() as unknown as D1Database;
    const repo = new SettingsRepository(db);
    const settings = await repo.get('guild-123');
    expect(settings).toEqual(defaultGuildSettings);
    expect(settings.welcomeEnabled).toBe(false);
    expect(settings.autoRoleIds).toEqual([]);
  });

  it('saves and retrieves settings', async () => {
    const db = new MockD1() as unknown as D1Database;
    const repo = new SettingsRepository(db);
    const custom: GuildSettings = {
      ...defaultGuildSettings,
      welcomeEnabled: true,
      welcomeMessage: 'Hello there!',
      autoRoleIds: ['role-1', 'role-2'],
    };
    await repo.save('guild-456', custom);
    const retrieved = await repo.get('guild-456');
    expect(retrieved.welcomeEnabled).toBe(true);
    expect(retrieved.welcomeMessage).toBe('Hello there!');
    expect(retrieved.autoRoleIds).toEqual(['role-1', 'role-2']);
  });
});
