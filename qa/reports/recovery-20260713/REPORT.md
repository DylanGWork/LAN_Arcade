# LAN Arcade NFS Recovery Report

Date: 2026-07-13 AEST

## Outcome

The arcade is serving again and the recoverable native download library has been rebuilt. The recovery is not a bit-for-bit restoration of the deleted NFS tree: it is a checksum-verified reconstruction from the Git repository, VM caches, Dylan-provided local archives, and fresh upstream package acquisition performed by the existing intake scripts.

Current public checks:

- Game Library: HTTP 200
- Browser-stream controller: HTTP 200
- Static launcher audit: 159 of 159 entry points pass
- Public external dependencies: zero detected in HTML/CSS
- Player-facing blocked guide links: zero detected
- Library discovery smoke: pass
- Deployment safety suite: pass

## Incident

A destructive sync crossed into the mounted NFS destination and removed most of `/srv/lan-arcade/native-downloads`. There was no usable pre-incident snapshot. The TrueNAS snapshot named `post-delete-baseline-2026-07-12_21-15` was created after deletion and is not a recovery source.

The unsafe pattern was remote shell syntax embedded in a double-quoted PowerShell SSH command. PowerShell expanded a remote variable before the command reached the VM, leaving an unintended destination. This pattern is now explicitly prohibited in project rules.

## Recovered Storage

Live NFS root: `/srv/lan-arcade/native-downloads`

- 129 top-level directories
- 8,541 files
- 38,598,425,074 bytes
- 124 top-level native package manifests
- zero incomplete `.part`, `.tmp`, or `.download` files
- zero broken symlinks
- web-facing bind mount is read-only

Promotion receipts:

- `core-payload-promotion.json`: 2,669 files/links, 3,170,435,135 bytes
- `package-shelves-promotion.json`: 4,164 files/links, 4,935,130,994 bytes
- `native-next-ten-promotion.json`: 97 files/links, 10,416,832,484 bytes
- `native-core-promotion.json`: 150 files/links, 17,324,896,139 bytes
- `final-batches-promotion.json`: 1,313 files/links, 2,555,979,048 bytes
- `native-index-metadata-promotion.json`: 64 bounded HTML replacements with verified local backups

The source staging tree remains preserved at:

`/home/dylan/LAN_Arcade/tmp/recovery-staging-20260713/native-downloads`

Previous native shelf HTML is backed up at:

`/home/dylan/LAN_Arcade/tmp/metadata-backups/20260713-native-shelves`

## Recovered Collections

### Game Boy

- EmulatorJS runtime restored and patched
- 2,184 archive ROM records reconstructed
- 743 selected playable Game Boy/Game Boy Color links reconstructed
- 79 Game Boy and 664 Game Boy Color selected entries
- sample Adventures of Lolo launch smoke passed

The complete 743-title collection has not received a fresh gameplay run.

### Classic PC

- 24 Dylan-provided archives transferred with matching SHA-256 hashes
- 24 of 24 imported
- 16 browser packages prepared
- 8 entries remain raw, ISO-based, Win3x, or otherwise not browser-ready
- local js-dos 8.4.0 runtime restored
- Classic PC shelf rebuilt with 28 entries and 16 browser packages

Observed state:

- SimAnt: browser smoke pass
- Oregon Trail, Prince of Persia, and Dune II: launch reached; meaningful gameplay still needs recertification
- SimCity: current rebuilt js-dos path crashes with `RangeError: offset is out of bounds`
- Lemmings: alternate browser/runtime compatibility remains unresolved

### Native And Streamed Games

Reconstructed payload families include the public Debian package shelves, shared Debian pool, browser-stream runtime/cache, intake assets, and the large native clients/servers represented by the 124 manifests.

The browser-stream Docker image was rebuilt and all 11 configured lifecycle tests passed:

- Ace of Penguins
- Battle Tanks
- FreedroidRPG
- Frozen Bubble
- Liquid War
- Micropolis
- Numpty Physics
- Pingus
- Sopwith
- SuperTux
- TuxMath

A real guest launch of Pingus through the public controller reached a running container and then shut down cleanly.

## Catalog

The rebuilt canonical registry reports:

- 1,112 distinct canonical titles
- 1,119 canonical entities including seven collection wrappers
- 1,455 source records
- 879 titles with local payload evidence
- 883 local payload records
- 124 native package manifests
- 159 top-level launcher/shelf cards

The 159 figure is not the game count. It is the number of top-level cards and collection launchers.

## Known Losses And Gaps

Confirmed loss:

- Pre-incident browser-stream per-account save directories were deleted. The save root was recreated empty.

Not proven recoverable:

- Any NFS-only artifact that was not represented in Git, VM caches, Dylan-provided archives, or reconstructible package scripts.
- Exact pre-incident versions for payloads rebuilt from current upstream sources.

Operational gap:

- `lan-arcade-browser-stream-control.service` is enabled but currently inactive. A manually started controller process is serving the endpoint. The unit should be transitioned back to systemd ownership during an approved privileged maintenance window.

Readiness gap:

- Readiness currently reports 0 Ready, 1,111 Limited, and 213 Research entries.
- The readiness unit tests pass, but the live invariant fails because old Pillage First, SimCity, and Tank Arena receipts no longer match the rebuilt catalog source fingerprints.
- Evidence was not rewritten or falsely promoted. Fresh full-flow, blocked-network gameplay receipts are required.

## Safety Changes

- The web-facing NFS bind is read-only.
- Public deployment paths no longer use destructive `rsync --delete`.
- Deployment target validation rejects root, escaped, mounted, and mount-containing targets.
- Package builders require explicit VM-local staging and reject public/NFS destinations.
- Native payload promotion is additive, checksum-verified, and refuses differing existing files.
- Metadata-only promotion permits only HTML/CSS, creates local backups, uses atomic replacement, and verifies hashes.
- Recursive ownership changes are constrained with `find -xdev`.
- Project rules prohibit double-quoted PowerShell SSH commands containing remote variables, loops, or command substitution.
- Recovery staging is retained after promotion.

## Verification

Passing:

- `npm run qa:offline-links`
- `npm run qa:blocked-guides`
- `npm run qa:static`
- `npm run qa:library-discovery`
- `bash qa/deployment-safety.sh`
- `npm run qa:git-identity`
- Python compile checks for recovery/sanitizer/promotion scripts
- shell syntax checks for changed deployment and lifecycle scripts

Expected follow-up failure:

- `npm run qa:readiness` fails only at the live invariant after its eight core tests pass. This is the honest stale-evidence condition described above.

Repository-wide `git diff --check` also reports pre-existing trailing whitespace in parallel game-intake CSV changes. Those unrelated files were not altered by recovery work.

## Next Safe Actions

1. Commit and push only the scoped recovery and deployment-safety changes.
2. Run fresh T3/T4 blocked-network gameplay certification, starting with Pillage First, Tank Arena, SimCity/Classic PC, and representative Game Boy/native titles.
3. Move the browser-stream controller from the manual process back under its enabled systemd unit.
4. Verify TrueNAS recurring snapshots and run a documented restore drill.
5. Keep the recovery staging and metadata backups until the restore drill and recertification wave are complete.
