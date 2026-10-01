# Reef Keepers (working title)

A cozy co-op Roblox game: grow a living coral reef, attract rare sea creatures, and visit your friends' reefs.

- **Design plan:** [`docs/DESIGN.md`](docs/DESIGN.md): vision, core loop, economy, monetization, live ops, launch plan, metrics, and risks.
- **Prototype:** the "one-coral prototype" from the plan's next steps, as a [Rojo](https://rojo.space) project.
- **Economy simulator:** [`tools/economy_sim.py`](tools/economy_sim.py), which plays through days 1, 7, and 30 against the same balance file the game uses.

## Run the prototype

1. Install [Roblox Studio](https://create.roblox.com/) and Rojo (`aftman install` uses the pinned version in `aftman.toml`, or install the Rojo Studio plugin plus CLI yourself).
2. Build a place file and open it:
   ```sh
   rojo build -o ReefKeepers.rbxl
   ```
   Or run `rojo serve` and connect from the Rojo plugin in Studio for live sync.
3. Press Play. You spawn next to your plot with one Staghorn coral already growing and 20 pearls.
4. Tap an empty sand slot to plant the selected coral, tap a coral marked **Ready!** to harvest, and tap the yellow pad to buy a slot.

Saves work in Studio only when **Game Settings → Security → Enable Studio Access to API Services** is on. Otherwise the game runs with in-memory saves and prints a warning.

## What the prototype covers

| Plan item | Where |
|---|---|
| Reef plot with 6 starting slots, expandable to 40, each slot 1.5× the last | `src/server/ReefService.luau`, `ReefMath.slotCost` |
| Corals on real-time timers, computed from the planted timestamp (offline growth included, capped at 8 h) | `src/shared/ReefMath.luau` |
| All balance values in one place, editable without code changes | `src/shared/Balance.json` |
| Server-authoritative currency and growth; the client only renders attributes | `ReefService.onSlotClicked`, `onBuySlot` |
| Validated, rate-limited requests (ownership, reach distance, token bucket) | `ReefService.luau` (`allow`, `inReach`, `onSelectCoral`) |
| DataStore saving with retries, session locking, autosave, save on leave and shutdown | `src/server/PlayerStore.luau` |
| Analytics: onboarding funnel and pearl sources/sinks | `logOnboarding`, `logPearls` in `ReefService.luau` |
| Phone first: big buttons, safe-area HUD, content streaming, one timer loop at 4 Hz | `src/client/init.client.luau`, `default.project.json` |
| Return hook: HUD always shows the next coral to mature | client timer loop |

## Visuals and effects

Everything is built from parts and Roblox's built-in effects in code, so there is nothing to upload. Decoration is created on each client and never replicated, which keeps server and network costs low.

![Procedural coral models](docs/coral_preview.png)

| What | Where |
|---|---|
| A distinct model for each coral, 9 to 27 parts each, that grows from a small fragment to full size over its first cycle | `src/shared/CoralModels.luau`, `src/client/CoralRenderer.luau` |
| A sparkle on ready corals; a pearl burst, flying pearls, a floating "+N", and a sound on harvest; a sand puff on planting; new slots rising out of the sand | `src/client/Effects.luau` |
| Fish that circle each reef, one more for every 2 corals (up to 10), plus a school at spawn | `src/client/Fish.luau` |
| A coral garden at spawn, rocks, swaying kelp, flickering sunbeams, bubble vents, drifting plankton, and a water surface | `src/client/WorldDecor.luau` |
| Underwater lighting: atmosphere haze, bloom, color tint, sun rays | `Lighting` in `default.project.json` |
| Sand plots with rock borders and name signs, round sand slots, a glowing gold buy pad | `buildPlot` / `createSlot` in `ReefService.luau` |

Sounds use built-in Roblox placeholder sounds (`SOUNDS` in `Effects.luau`). Swap in your own uploaded audio IDs there.

To preview coral shapes without Studio, run `python3 tools/preview/render_corals.py`. It runs the real `CoralModels.luau` in the `luau` CLI against a small mock of Roblox's math types and writes `docs/coral_preview.png`. It needs matplotlib.

Not built yet: creature conditions, reef health, collection book, prestige, social features, shop rotation, monetization, custom audio, and uploaded meshes. The design doc's system order is the suggested build order.

## Project layout

```
default.project.json     Rojo tree (Workspace, Lighting, script locations)
src/shared/              ReplicatedStorage.Shared
  Balance.json           coral stats, costs, caps (loaded as a ModuleScript)
  ReefMath.luau          pure growth/cost math used by server, client, and the sim
  CoralModels.luau       procedural coral models built from parts
src/server/              ServerScriptService.Server
  init.server.luau       entry point
  PlayerStore.luau       save/load with session lock
  ReefService.luau       plots, planting, harvesting, slot purchases
src/client/              StarterPlayerScripts.Client
  init.client.luau       HUD, coral picker, slot timers; starts the modules below
  CoralRenderer.luau     draws and grows corals on slot tiles
  Effects.luau           harvest/plant/slot effects and sounds
  Fish.luau              fish schools
  WorldDecor.luau        seafloor decoration
tools/economy_sim.py     economy simulator
tools/preview/           offline coral preview renderer
tests/reefmath_parity.py checks ReefMath.luau against the simulator's Python mirror
docs/DESIGN.md           full design and development plan
```

## Tuning the economy

```sh
python3 tools/economy_sim.py
```

The simulator plays a greedy player through a fixed login schedule (three sessions on day 1, then two 10-minute sessions per day) and prints the reef at the end of days 1, 7, and 30, plus the active play time between unlocks. Gaps outside the 2 to 30 minute target from the design doc are flagged. Edit `src/shared/Balance.json` and rerun; the game picks up the same values.

With the current starting values the early game stays inside the target, and gaps past day 7 grow beyond 30 minutes. That is where prestige and the rotating Fan-coral shop, which the simulator does not model yet, need to take over.

The harvest math in `economy_sim.py` mirrors `ReefMath.luau`. Keep the two in sync when either changes. `tests/reefmath_parity.py` runs 2,000 random cases through both and fails on any mismatch; it needs the [`luau` CLI](https://github.com/luau-lang/luau/releases) on `PATH` (or set `LUAU=/path/to/luau`).
