# DOS Tycoon Batch Smoke - 2026-06-19

Private My Abandonware intake batch. Raw files are on the NFS native shelf outside Git. All launch tests used DOSBox under `bwrap --unshare-net`.

| Candidate | Status | Evidence | Notes |
| --- | --- | --- | --- |
| `simcity-classic-dos-ma` | smoke-pass | `qa/reports/private-tycoon/simcity-classic-dos-ma-20260619T101919Z/REPORT.md` | Started new city, selected/placed residential zoning, funds dropped to $19,900. |
| `sim-farm-dos-ma` | partial | `qa/reports/private-tycoon/sim-farm-dos-ma-20260619T102116Z/REPORT.md` | Reached farm map; no proven field/build action yet. |
| `railroad-tycoon-deluxe-dos-ma` | partial | `qa/reports/private-tycoon/railroad-tycoon-deluxe-dos-ma-20260619T102332Z/REPORT.md` | Direct `RRT.EXE` reached period/region selection; no route built yet. |
| `a-train-dos-ma` | blocked | `qa/reports/private-tycoon/a-train-dos-ma-20260619T101622Z/REPORT.md` | Flattened launch invoked `AT.EXE` but no visible game screen. Needs setup/manual investigation. |
| `black-gold-dos-ma` | blocked | `qa/reports/private-tycoon/black-gold-dos-ma-20260619T101711Z/REPORT.md` | Reaches code-card ownership verification. Code table remains private and must not be exposed in Git/public pages. |

## Harness Lesson

DOSBox launch recipes must avoid long extracted folder names. Flatten or copy the executable directory into a short DOS root before running commands.
