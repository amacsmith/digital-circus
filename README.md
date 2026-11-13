# GLITCHTOP

> The circus is still rendering. You're the act.

An original Roblox party game set inside a circus that a malfunctioning ringmaster program, **BARKER.EXE**, generates live. The place file ships with an **empty Workspace**: the hub, every arena, every UI screen and every cosmetic is built by Luau at runtime.

Original setting, characters and names. Not affiliated with any existing show or game.

> **Status:** written and desk-checked, **not yet run in Roblox Studio**. Expect a first-playtest pass for tuning and typos. See [Verification](#verification).

## The loop

| Step | What happens |
| --- | --- |
| **Midway** (22s) | Players roam today's generated hub, spend tickets, claim rewards. |
| **Compile** (5s) | BARKER.EXE picks an act and a glitch mutator, then generates a brand-new arena from a fresh seed. |
| **Act** (60–90s) | Everyone not sitting out is teleported in and performs. |
| **Curtain call** | Tickets and applause are paid out, the arena is deleted, repeat. |

### What makes it different

- **The Daily Build.** The Midway (palette, booth layout, ferris wheel, debris) is generated from the UTC date. Every server shares "build #20261113" today; tomorrow it is a different circus.
- **Acts × mutators.** Four acts, each generated per round, multiplied by seven glitch mutators (`gravity.cfg Missing`, `Framerate Uncapped`, `lights.dll Unloaded`, `Scale = 0.5`, a 2x-pay `GOLDEN BUILD`, …).
- **The crowd meter.** A server-wide bar that everyone fills by performing. When it tops out, tickets physically rain on the Midway.
- **BARKER.EXE.** A floating top hat with a monitor for a face that narrates everything in a typewriter subtitle.

### Acts

| Act | Mode | Idea |
| --- | --- | --- |
| `TIGHTROPE.DLL` | race | A 30-step obstacle course compiled from the seed: beams, flicker pads, checkpoints. Falls return you to your checkpoint. |
| `FLOOR_NOT_FOUND` | survive | A 10×10 stage garbage-collected tile by tile, faster and faster. |
| `BALLOON.POP()` | collect | Score attack over generated spiral towers. Gold pays 5x; black "virus" balloons launch you. |
| `FOLLOW_SPOT` | survive | Only what the spotlight touches gets rendered. It wanders and shrinks. |

## Monetization

Everything is declared in `src/shared/Config.luau`. Paste ids from the Creator Dashboard; `id = 0` means "not on sale" live and "grants for free" in Studio, so the whole loop is testable before publishing.

| Item | Type | Why it sells |
| --- | --- | --- |
| VIP Box Seat | pass | 2x tickets forever, gold `[VIP]` nameplate. |
| Stagehand Sneakers | pass | Faster on the Midway only, so acts stay fair. |
| Lucky Claw | pass | Doubles Epic+ capsule weights (the UI shows the adjusted odds). |
| Ticket bundles ×4 | product | Soft-currency top-ups with escalating bonus. |
| Standing Ovation | product | 2x tickets for **everyone** in the server for 15 min, stacks, announced by name. |
| Second Take | product | Revive, offered at the moment of elimination. Stored as a token that never expires, so a late purchase is never wasted. |
| Director's Cut | product | Choose the next act for the whole server. |

Retention systems that feed it: 7-day streak ladder, playtime gift, Encore prestige (+25% permanent per reset), friends-in-server bonus (+5% each, cap 5), Premium bonus (+10%), and a global "Top Billing" board.

### Guardrails already built in

- **Receipts are idempotent.** Purchase ids are stored in the profile; `PurchaseGranted` is returned only after a successful save; nothing is granted to a profile that failed to load.
- **Capsule odds are exact and disclosed.** Server and UI read the same `Config.capsuleOdds()` table. Pity guarantees Epic+ every 40 pulls. Every item also has a fixed direct price.
- **Regional compliance.** `PolicyService.ArePaidRandomItemsRestricted` is checked per player and fails closed; restricted players only get direct purchase.
- **No pay-to-win in acts.** Paid speed applies on the Midway only.
- **Server-authoritative.** The client never reports currency; remotes are rate limited and argument-checked.

## Run it

**With Rojo**

```bash
rojo serve default.project.json
```

Connect from the Rojo plugin in Studio, then press Play.

**Or build a place file**

```bash
rojo build default.project.json -o Glitchtop.rbxlx
```

**Before publishing**

1. Enable *Studio Access to API Services* (Game Settings → Security) so DataStores work.
2. Create the passes and developer products, paste their ids into `Config.Passes` / `Config.Products`.
3. Playtest with 2+ players (Test → Start) to exercise survive-mode endings and the revive offer.

## Layout

```
src/shared   Config (all data), Net (remotes), Rng (seeded helpers), Build (part factory)
src/server   Main.server + Services/ (Data, Pass, Economy, Monetization, Capsule,
             Cosmetic, Reward, Movement, WorldGen, ActDirector) + Acts/
src/client   Main.client (HUD, panels, FX) + Ui (declarative kit)
```

### Extending

- **New act:** add a module to `src/server/Acts` returning `{ id, build(ctx), run(ctx), onFall? }` and one row in `Config.Acts`. The director, UI and Director's Chair pick it up automatically.
- **New mutator / cosmetic / product / palette:** add a row in `Config.luau`. Products reuse grant handlers by `kind`.
- **New panel:** add a `builders.X` function in the client returning `{ title, rows, footer }`.

## Verification

- Bracket balance and remote-name consistency were checked by script across all 21 files.
- Static analysis with `luau-lsp` and a `rojo build` were **not** run: executing the downloaded tool binaries was blocked in the authoring environment.
- Nothing has been executed inside Roblox. Known areas to tune on first playtest: jump-gap sizes in `Tightrope` under the `Lag`/`Tiny` mutators, payout curve vs. capsule prices, and UI scale on phones.
- `DataService` has no cross-server session lock. For a large live game, back it with ProfileStore; the public API is small enough to keep.
