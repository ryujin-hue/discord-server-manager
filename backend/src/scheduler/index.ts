import type { EngagementService } from '../services/engagementService.js';
import type { GuildService } from '../services/guildService.js';
import type { KnownGuildRepository } from '../db/repositories.js';

export type SchedulerOptions = {
  /** How often the scheduler wakes up, in milliseconds. */
  intervalMs?: number;
  /** Minimum age between two snapshot rounds, in milliseconds. */
  snapshotIntervalMs?: number;
};

export type SchedulerClock = {
  now(): number;
  setInterval(handler: () => void, ms: number): unknown;
  clearInterval(handle: unknown): void;
};

const systemClock: SchedulerClock = {
  now: () => Date.now(),
  setInterval: (handler, ms) => setInterval(handler, ms),
  clearInterval: (handle) => clearInterval(handle as NodeJS.Timeout),
};

/**
 * Runs scheduled announcements and the daily member-count snapshot job.
 * Announcements live in SQLite, so pending ones survive a process restart.
 */
export class Scheduler {
  private readonly intervalMs: number;
  private readonly snapshotIntervalMs: number;
  private readonly clock: SchedulerClock;
  private handle: unknown;
  private lastSnapshotAt = 0;

  constructor(
    private readonly engagement: EngagementService,
    private readonly guildService: GuildService,
    private readonly knownGuilds: KnownGuildRepository,
    options: SchedulerOptions = {},
    clock: SchedulerClock = systemClock,
  ) {
    this.intervalMs = options.intervalMs ?? 15_000;
    this.snapshotIntervalMs = options.snapshotIntervalMs ?? 6 * 60 * 60 * 1000;
    this.clock = clock;
  }

  start(): void {
    if (this.handle !== undefined) {
      return;
    }
    this.handle = this.clock.setInterval(() => {
      void this.tick();
    }, this.intervalMs);
  }

  stop(): void {
    if (this.handle === undefined) {
      return;
    }
    this.clock.clearInterval(this.handle);
    this.handle = undefined;
  }

  /** Processes due announcements and, when due, records the daily snapshot. */
  async tick(): Promise<void> {
    const now = this.clock.now();
    const pending = this.engagement.pendingAnnouncements();
    for (const announcement of pending) {
      if (Date.parse(announcement.scheduledAt) > now) {
        continue;
      }
      await this.engagement.sendAnnouncement(announcement);
    }

    if (this.lastSnapshotAt === 0 || now - this.lastSnapshotAt >= this.snapshotIntervalMs) {
      this.lastSnapshotAt = now;
      await this.collectSnapshots();
    }
  }

  private async collectSnapshots(): Promise<void> {
    for (const guildId of this.knownGuilds.list()) {
      try {
        await this.guildService.collectSnapshot(guildId);
      } catch {
        // A guild may be inaccessible; skip it and try again on the next round.
      }
    }
  }
}
