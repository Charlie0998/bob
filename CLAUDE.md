# Reef Keepers: notes for Claude

Cozy co-op Roblox reef tycoon. Rojo project; Luau code in `src/`, design doc in `docs/DESIGN.md`, feature tables in `README.md`.

## The user
- Young, non-technical, builds in Roblox Studio on a Mac. Keep replies short and plain.
- After each change, build `ReefKeepers.rbxl` and send it with SendUserFile.
- New images/sounds: the user uploads them in Studio (Asset Manager → Bulk Import) and pastes back a CSV of `Name,Asset ID,...`. Put IDs into `src/shared/Icons.json`, `Sounds.json` (`{id, volume}`), or `Textures.json`.

## Layout
- `src/shared/` → ReplicatedStorage.Shared: `Balance.json` (all tuning), pure modules (`ReefMath`, `ReefHealth`, `ShopRotation`, `ReefLevel`, `CreatureRules`), part-built models (`CoralModels`, `CreatureModels`, `DecorModels`), asset ID JSONs.
- `src/server/` → one Service per system, started in order by `init.server.luau`. `ReefService` owns plots, harvesting, currencies (`addCurrency`, `addInventory`, `toast`, `effect`, `activity` signal, `addMultiplier`). `PlayerStore` saves data with session locking; add new fields to both the `PlayerData` type and `newData()`.
- `src/client/` → `init.client.luau` builds the HUD and starts modules. `UIKit` holds `COLORS`, `FONTS`, `gloss`, `button`, `panel`, `icon`. Decoration and creatures are built on the client.
- `src/first/LoadingScreen.client.luau` → ReplicatedFirst.

## Rules
- Server validates every purchase and action; clients only send requests.
- UI colors only from `UIKit.COLORS`; keep text contrast ≥ 4.5:1.
- Keep the shared math and its Python mirror in `tools/economy_sim.py` in sync.

## Checks (no Studio here)
Tools are downloaded to the scratchpad if missing: `rojo` 7.4.4, `luau`, `luau-compile`, `luau-lsp` plus `globalTypes.d.luau` (from the luau-lsp repo).
```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
LUAU=path/to/luau python3 tests/reefmath_parity.py
python3 tests/contrast_check.py
python3 tools/economy_sim.py
rojo build -o ReefKeepers.rbxl
```
Commit and push to the working branch after each part.
