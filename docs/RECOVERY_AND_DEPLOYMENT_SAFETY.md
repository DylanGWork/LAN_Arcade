# Recovery And Deployment Safety

This document is mandatory reading before changing deployed payloads or the native-download NFS store.

## Storage Boundaries

- Repository and build staging: `/home/dylan/LAN_Arcade` on VM-local ext4.
- Writable native-download store: `/srv/lan-arcade/native-downloads` on NFS.
- Player-facing native-download path: `/var/www/html/mirrors/games/downloads/native`.
- The player-facing path must remain a read-only bind of the NFS store.
- Never put a writable NFS mount below a directory that a generator owns recursively.

Verify the boundary before deployment:

```bash
findmnt /srv/lan-arcade/native-downloads
findmnt /var/www/html/mirrors/games/downloads/native
qa/deployment-safety.sh
```

## Destructive Operation Rules

- Do not use raw `rsync --delete` against deployed trees.
- Do not recursively delete, move, or change ownership on `/var/www/html/mirrors`, `/var/www/html/mirrors/games`, `/srv`, or an ancestor of a mount.
- Every per-game deployment target must pass `scripts/assert_safe_deploy_target.sh`.
- Deployment scripts must refuse empty targets, the deployment root itself, escaped paths, mount points, and targets containing mount points.
- Prefer additive copy into a verified staging tree. Retain stale files until a separately reviewed cleanup.
- Never promote directly from an unverified download or intake folder.

## Required Recovery/Promotion Flow

1. Check `git status`, mounts, free space, service state, and current snapshots.
2. Verify that a usable pre-change snapshot actually exists. A snapshot created after damage is not a rollback.
3. Back up user databases and save data separately from replaceable game payloads.
4. Build under an explicit VM-local staging root, such as `tmp/recovery-staging-YYYYMMDD`.
5. Generate a file inventory and SHA256 manifest.
6. Run package/archive integrity checks and meaningful launcher smoke tests from staging.
7. Copy to `/srv/lan-arcade/native-downloads` without deletion.
8. Verify the same files through the read-only player-facing mount.
9. Regenerate the canonical registry/readiness data and run the applicable QA.
10. Only then restart an on-demand service or promote readiness.

Package cache builders require `LAN_ARCADE_NATIVE_DOWNLOAD_ROOT` to point to a local staging directory. They reject `/var/www`, `/srv`, and NFS.

## PowerShell To SSH Rule

Do not place remote shell variables or loops inside a double-quoted PowerShell `ssh` command. PowerShell can expand variables before the command reaches GannanNet. This caused the July 2026 deletion incident when a remote per-game variable became empty.

Use one of these patterns instead:

- a checked-in script executed on the VM;
- a literal remote command with no remote variables;
- an uploaded, reviewed script or patch whose checksum is recorded.

Do not work around this rule with extra escaping for destructive commands.

## July 2026 Incident

An intended per-game sync expanded an empty target and copied `local-games/` to the mirror root with deletion enabled. The destination contained the native-download NFS mount, so most cached game payloads were removed. No verified pre-incident TrueNAS snapshot existed.

Permanent controls added after the incident:

- player-facing NFS bind is read-only;
- mount-aware target guard;
- no deletion-enabled sync in public deployment entrypoints;
- ownership changes use `find -xdev`; and
- `qa/deployment-safety.sh` exercises the guard and scans entrypoints.

These controls reduce risk but do not replace backups, snapshots, manifests, or full-flow QA.
