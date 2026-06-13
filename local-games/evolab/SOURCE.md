# EvoLab Source

This LAN Arcade offline build is based on EvoLab.

Upstream: https://github.com/simongonzalezdc/EvoLab
Commit: ad46b78e65d07de022b67d7081847ef420a0564e
License: MIT; see LICENSE.

Local LAN Arcade changes:

- Built with Vite --base ./ so dynamic chunks load under /mirrors/evolab/.
- Removed remote font loading and kept bundled assets offline-friendly.
- Defaulted background music off and guarded Tone.js startup errors.
- Made Manual Mode nudge the player species with WASD/arrow keys, changed the player species to cyan, started it near the center, collapsed the biome legend, and made the main menu minimizable.
- Added narrow-screen layout guards so panels do not pile up over the playfield on phones.
- Added visible food feedback: wider glucose pickup radius, eating sparkles, floating +ATP labels, and a HUD Food Eaten counter.
- Reworked the trait editor with +/- buttons, number inputs, trait-specific change ranges, and inline DNA budget feedback instead of alert popups.
- Fixed glucose respawn timing: resource updates use seconds, so respawn is 8 seconds rather than an accidental 8000 seconds.
