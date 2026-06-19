# Source Notes

Created: 2026-06-19

Use this file to track discovery sources, useful search terms, and source-level
rules for future game intake batches.

## Initial Sources

### My Abandonware

- URL: `https://www.myabandonware.com/`
- Use: discovery, historical metadata, platform filtering, candidate names.
- Rule: do not treat abandonware availability as redistribution permission.
- Good candidate buckets to investigate: tycoon/management games, city builders,
  4X/strategy games, DOS/Windows classics, demos/shareware/freeware releases,
  and titles where rights-holder redistribution is explicit.
- Default status for unclear commercial full games: `legal-review`.

## Search Terms To Try

- `freeware tycoon game`
- `open source tycoon game`
- `shareware strategy game dos`
- `public domain dos game`
- `source port sim game open source`
- `classic strategy game freeware release`
- `LAN multiplayer old game open source`

## Notes For Future Agents

- Keep candidate notes small and commit-friendly.
- Put cached large files on `/srv/lan-arcade/native-downloads/intake/`.
- Put private Dylan-provided files on a private VM-local shelf and label them
  private; do not push those files to GitHub.
- A game is not playable until a no-internet smoke test reaches a real gameplay
  or setup state with screenshots/log evidence.
