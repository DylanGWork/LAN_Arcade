# Phase 6 Family Accounts And Save Isolation Review - 2026-07-11

## Result

PASS for the account foundation and the currently adapted browser-save lane.

## Security Boundary

- Anonymous `GET /accounts` now returns 401 instead of enumerating LAN accounts.
- The first account on a new install is forced to the bootstrap admin role.
- Later anonymous sign-ups are forced to ordinary adult accounts.
- Anonymous callers cannot assign child, admin, service, guest, or parent
  relationships.
- Only signed-in adult/admin accounts can create child accounts.
- A child is always attached to the signed-in family organizer.
- Child, guest, and service accounts cannot create family accounts.
- Only an admin can create admin or service accounts.
- Adult family listings contain the adult and their children; child listings contain
  only that child; admin listings contain all accounts.

## Player Experience

- Signed-in adult/admin players can create a child account from the Player panel.
- Authorized family players appear under `Switch player`.
- Choosing a family player opens the normal sign-in form with the username filled in;
  the player still supplies their password.
- Guest mode remains available without account setup.
- The player panel states that recent activity and supported saves are account
  separated.

## Save Isolation

The shared browser-save adapter was tested through an A -> B -> A switch:

- account-local browser keys differed;
- account B started without account A's save;
- each token wrote a distinct server slot;
- returning to account A restored only A's payload.

The API unit suite now also stores the same game/slot for two real test accounts and
proves neither can read or overwrite the other's payload.

## Deployment And Evidence

- Transaction-consistent backup:
  `/home/dylan/backups/lan-arcade/user-data/20260711T061750Z`
- Backup SQLite quick check: `ok`; ten tables enumerated and counted.
- Rebuilt and recreated only `lan-arcade-api`.
- API health passed through the deployed HTTPS route.
- Family browser smoke:
  `qa/reports/family-account-browser/result.json`
- Save adapter smoke:
  `qa/reports/account-save-isolation/result.json`

## Regression Results

- Arcade API: 10/10 tests pass.
- Family account browser smoke: pass with no page errors or external requests.
- Account save isolation browser smoke: pass.
- Readiness browser smoke: pass.
- Library discovery/recent/favorites smoke: pass.
- Anonymous account list: 401.
- Authenticated organizer account list: 200.

## Limits Kept Explicit

- Only Breachline Tactics, Circuit Foundry, and Outpost Siege currently use the shared
  account save adapter end to end.
- EvoLab has account-namespaced browser storage but is not yet cross-device synced.
- EmulatorJS, js-dos, native clients, and hosted-game saves are not yet account
  isolated and must remain marked as needing adapter work.
- Password reset and verification are not connected to the local mail server yet.
- Sessions remain browser-local bearer tokens.
- This phase does not turn Pillage First into a shared multi-account world.
