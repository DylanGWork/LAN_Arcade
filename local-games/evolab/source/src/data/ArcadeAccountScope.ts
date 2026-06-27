const ACCOUNT_STORAGE_KEY = 'lanArcadeAccount.v1';

interface StoredArcadeAccount {
  token?: string;
  account?: {
    id?: string;
    username?: string;
    displayName?: string;
    email?: string;
  };
}

export interface ArcadeAccountScope {
  mode: 'guest' | 'account';
  accountId: string;
  label: string;
  databaseName: string;
  storageSuffix: string;
}

function getStorage(): Storage | null {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return null;
    return window.localStorage;
  } catch {
    return null;
  }
}

function sanitizeSuffix(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 96) || 'unknown';
}

function readStoredAccount(): StoredArcadeAccount | null {
  const storage = getStorage();
  if (!storage) return null;

  try {
    const raw = storage.getItem(ACCOUNT_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StoredArcadeAccount;
    if (!parsed.token || !parsed.account?.id) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function resolveArcadeAccountScope(): ArcadeAccountScope {
  const stored = readStoredAccount();
  const account = stored?.account;

  if (!account?.id) {
    return {
      mode: 'guest',
      accountId: '',
      label: 'Guest browser',
      databaseName: 'EvoLabDB',
      storageSuffix: '',
    };
  }

  const storageSuffix = sanitizeSuffix(account.id);
  return {
    mode: 'account',
    accountId: account.id,
    label: account.displayName || account.username || account.email || 'Signed-in account',
    databaseName: `EvoLabDB_account_${storageSuffix}`,
    storageSuffix,
  };
}

export function scopedLocalStorageKey(baseKey: string): string {
  const scope = resolveArcadeAccountScope();
  return scope.mode === 'account' ? `${baseKey}.account.${scope.storageSuffix}` : baseKey;
}
