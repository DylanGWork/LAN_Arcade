(function () {
  'use strict';

  const ACCOUNT_STORAGE_KEY = 'lanArcadeAccount.v1';
  const DEFAULT_ADAPTER = 'browser-localstorage';

  function storedAccount() {
    try {
      const saved = JSON.parse(localStorage.getItem(ACCOUNT_STORAGE_KEY) || 'null');
      if (saved && saved.token && saved.account && saved.account.id) return saved;
    } catch (error) {
      console.warn('LAN Arcade account read failed', error);
    }
    return null;
  }

  function accountId() {
    const saved = storedAccount();
    return saved && saved.account ? saved.account.id : '';
  }

  function localKey(baseKey) {
    const id = accountId();
    return id ? `${baseKey}.account.${id}` : baseKey;
  }

  function claimLegacySave(legacyKey, accountKey) {
    const id = accountId();
    if (!id || accountKey === legacyKey) return;
    if (localStorage.getItem(accountKey)) return;
    const legacy = localStorage.getItem(legacyKey);
    if (!legacy) return;
    const claimKey = `${legacyKey}.claimedByAccount.v1`;
    const claimedBy = localStorage.getItem(claimKey);
    if (claimedBy && claimedBy !== id) return;
    localStorage.setItem(accountKey, legacy);
    localStorage.setItem(claimKey, id);
  }

  async function apiRequest(path, options) {
    const response = await fetch(`${window.location.origin}/arcade-api/${path.replace(/^\//, '')}`, options);
    if (response.status === 404) return { notFound: true };
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.error || `Request failed with ${response.status}`);
    return body;
  }

  function createSlot(options) {
    const adapter = options.adapter || DEFAULT_ADAPTER;
    const slot = options.slot || 'main';
    const legacyKey = options.legacyKey;
    const gameId = options.gameId;
    const label = options.label || `${gameId} save`;
    const account = storedAccount();
    const token = account ? account.token : '';
    const key = localKey(legacyKey);
    let saveTimer = 0;
    let lastPayload = '';

    if (!legacyKey || !gameId) throw new Error('createSlot requires gameId and legacyKey');
    claimLegacySave(legacyKey, key);

    function notify(type, message, details) {
      if (typeof options.onStatus === 'function') options.onStatus({ type, message, details });
      if (type === 'error') console.warn(message, details || '');
    }

    async function putRaw(rawPayload, metadata) {
      if (!token) return null;
      return apiRequest('account/saves', {
        method: 'PUT',
        headers: {
          'content-type': 'application/json',
          'x-arcade-account-session': token,
        },
        body: JSON.stringify({
          adapter,
          gameId,
          slot,
          label,
          payloadEncoding: 'json',
          payload: rawPayload,
          metadata: Object.assign({ legacyKey, localKey: key }, metadata || {}),
        }),
      });
    }

    async function hydrate() {
      if (!token) {
        notify('guest', 'Guest saves stay on this browser.');
        return { mode: 'guest' };
      }
      try {
        const body = await apiRequest(`account/saves/${encodeURIComponent(adapter)}/${encodeURIComponent(gameId)}/${encodeURIComponent(slot)}`, {
          headers: { 'x-arcade-account-session': token },
        });
        if (body.notFound) {
          const localRaw = localStorage.getItem(key);
          if (localRaw) {
            await putRaw(localRaw, { importedFromBrowser: true });
            notify('synced', 'Imported browser save into this account.');
          }
          return { mode: 'empty' };
        }
        const raw = body.save && typeof body.save.payload === 'string' ? body.save.payload : '';
        if (!raw) return { mode: 'empty' };
        localStorage.setItem(key, raw);
        lastPayload = raw;
        if (typeof options.applyPayload === 'function') {
          options.applyPayload(JSON.parse(raw), 'server', body.save);
        }
        notify('loaded', 'Loaded account save.');
        return { mode: 'loaded', save: body.save };
      } catch (error) {
        notify('error', 'Account save sync failed; using browser save.', error);
        return { mode: 'error', error };
      }
    }

    function save(payload, metadata) {
      const raw = typeof payload === 'string' ? payload : JSON.stringify(payload);
      localStorage.setItem(key, raw);
      if (!token || raw === lastPayload) return;
      lastPayload = raw;
      window.clearTimeout(saveTimer);
      saveTimer = window.setTimeout(() => {
        putRaw(raw, metadata).catch((error) => notify('error', 'Account save upload failed.', error));
      }, 300);
    }

    return { adapter, gameId, slot, key, account, hydrate, save };
  }

  window.LanArcadeAccountSaves = { storedAccount, localKey, createSlot };
}());
