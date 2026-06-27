/**
 * Tests for SaveSystem
 * Verifies save/load functionality
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { SaveSystem } from '../../src/data/SaveSystem';
import {
  resolveArcadeAccountScope,
  scopedLocalStorageKey,
} from '../../src/data/ArcadeAccountScope';

describe('SaveSystem', () => {
  let saveSystem: SaveSystem;

  beforeEach(() => {
    saveSystem = new SaveSystem();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('should create a save system instance', () => {
    expect(saveSystem).toBeDefined();
  });

  it('should have default settings', () => {
    const defaults = saveSystem.getDefaultSettings();

    expect(defaults).toBeDefined();
    expect(defaults.musicEnabled).toBeDefined();
    expect(defaults.soundEnabled).toBeDefined();
    expect(defaults.mutationRate).toBeGreaterThanOrEqual(0);
    expect(defaults.mutationRate).toBeLessThanOrEqual(1);
  });

  it('should have valid default mutation settings', () => {
    const defaults = saveSystem.getDefaultSettings();

    expect(defaults.mutationRate).toBeGreaterThanOrEqual(0);
    expect(defaults.mutationRate).toBeLessThanOrEqual(1);
    expect(defaults.mutationMagnitude).toBeGreaterThanOrEqual(0);
    expect(defaults.mutationMagnitude).toBeLessThanOrEqual(1);
    expect(defaults.beneficialBias).toBeGreaterThanOrEqual(0);
    expect(defaults.beneficialBias).toBeLessThanOrEqual(1);
  });

  it('should have accessibility settings', () => {
    const defaults = saveSystem.getDefaultSettings();

    expect(defaults.highContrastMode).toBeDefined();
    expect(defaults.reduceMotion).toBeDefined();
    expect(defaults.fontSize).toBeDefined();
  });

  it('should have auto-save settings', () => {
    const defaults = saveSystem.getDefaultSettings();

    expect(defaults.autoSave).toBeDefined();
    expect(defaults.autoSaveInterval).toBeGreaterThan(0);
  });

  it('should use the legacy guest IndexedDB name when no account is active', () => {
    const scope = saveSystem.getSaveScope();

    expect(scope.mode).toBe('guest');
    expect(scope.databaseName).toBe('EvoLabDB');
    expect(scopedLocalStorageKey('evolab_leaderboard')).toBe('evolab_leaderboard');
  });

  it('should namespace IndexedDB and localStorage when an arcade account is active', () => {
    vi.stubGlobal('window', {
      localStorage: {
        getItem: (key: string) => {
          if (key !== 'lanArcadeAccount.v1') return null;
          return JSON.stringify({
            token: 'session-token',
            account: {
              id: 'user/123',
              username: 'dylan',
              displayName: 'Dylan',
            },
          });
        },
      },
    });

    const accountSaveSystem = new SaveSystem();
    const scope = accountSaveSystem.getSaveScope();
    const resolved = resolveArcadeAccountScope();

    expect(scope.mode).toBe('account');
    expect(scope.accountId).toBe('user/123');
    expect(scope.label).toBe('Dylan');
    expect(scope.databaseName).toBe('EvoLabDB_account_user_123');
    expect(resolved.databaseName).toBe(scope.databaseName);
    expect(scopedLocalStorageKey('evolab_leaderboard')).toBe('evolab_leaderboard.account.user_123');
  });

  // Note: Skipping IndexedDB-dependent tests since they require a browser environment
  // Tests for saveSimulation, loadSimulation, saveSettings, loadSettings
  // would require mocking or a browser environment with IndexedDB
});
