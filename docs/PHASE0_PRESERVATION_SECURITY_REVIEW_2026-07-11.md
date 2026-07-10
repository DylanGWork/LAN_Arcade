# Phase 0 Preservation And Security Review - 2026-07-11

## Scope

This phase established a recoverable baseline before splitting Pillage First or
rebuilding the catalogue. It did not rebuild LAN Arcade, change the Pillage
deployment, or touch browser world storage.

## Preserved Baseline

Private preflight snapshot:

```text
/home/dylan/backups/lan-arcade/preflight/20260710T145813Z
```

The snapshot contains:

- a complete Git bundle at LAN Arcade commit `0af9eac`;
- the pre-existing tracked diff and untracked files;
- the exact modified Pillage First source diff and six untracked source files;
- the Pillage build script and focused QA scripts;
- the live, hub, combat, UI-preview, and inspect deployment trees;
- nginx configuration and generated public catalogue files;
- a transaction-consistent LAN Arcade SQLite snapshot;
- TravianZ application and database backups;
- Unciv and Mindustry persistent data;
- NFS package metadata, file count, and usage evidence.

All files passed the snapshot SHA-256 manifest. The Git bundle verified as a
complete history.

## Backup Repair

`scripts/backup_arcade_user_data.sh` no longer makes an unsafe plain copy when
the `sqlite3` command is absent. It now uses Python's SQLite online backup API,
changes the result to a standalone rollback-journal database, runs
`PRAGMA quick_check`, records table row counts, and fails when no safe backup
tool is available.

Verified post-change backup:

```text
/home/dylan/backups/lan-arcade/user-data/20260710T153900Z
```

Result:

- `quick_check=ok`;
- 10 application tables;
- account, player, session, and activity row counts preserved;
- account-data archive present;
- no SQLite WAL/SHM sidecars required;
- files are mode `0600`.

A disposable MariaDB restore test loaded the TravianZ application dump with one
application database and 61 tables.

## Credential And Permission Repair

- Removed literal TravianZ database credentials from current tracked setup code.
- New installations generate independent random database credentials.
- Compose now refuses to start without required secret values.
- Rotated both active TravianZ database credentials.
- Recreated the TravianZ database and web containers with the rotated values.
- Verified root authentication, application authentication, database health,
  and the TravianZ HTTP page.
- Restricted the runtime PHP credential file to Dylan plus the web-service UID.
- Restricted the dormant Unciv authentication file to its owner.
- Added ignore rules for environment files, secret directories, browser/world
  exports, SQLite3 files, and operator logs.
- Added `npm run qa:secrets` to reject tracked secret paths, literal secret
  assignments, insecure Compose defaults, private keys, and common GitHub token
  formats.

The old committed credentials must be treated as permanently exposed, but they
are no longer active.

## Runtime Data Root

Created the account-owned storage root:

```text
/srv/lan-arcade/user-data/accounts
```

It is owned by `dylan` and mode `0700`.

## Verification

Passed:

- shell syntax validation;
- TravianZ Compose configuration validation;
- tracked-secret scan;
- Git identity validation;
- SQLite online backup and verification;
- disposable TravianZ database restore;
- TravianZ root and application authentication;
- TravianZ database health and HTTP response;
- LAN Arcade library HTTP response;
- Arcade API `/arcade-api/health`.

## Remaining Gate

Dylan's live Pillage First world `s-dd7a` is browser OPFS data in Windows
Chrome Profile 2. It cannot be backed up from the VM. Pillage source extraction
may proceed without changing deployment, but no Pillage cutover or origin change
is allowed until that world has been exported and test-imported in a disposable
browser profile.

NFS package content remains a single storage copy. This phase preserved its
metadata and checksums; a second-storage snapshot remains a later operations
requirement.
