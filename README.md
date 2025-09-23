Bee Hive — Design Doc (Godot 4.4.1 · GDScript · 2D)

## Pitch

Controller-first, calm real-time hive-builder roguelite. Start from a single Queen cell, expand tile-by-tile, assign bees, run Harvests & Contracts, and survive to the boss before the swarm/end.

## Design Pillars

- Controller-first
- Readable UI
- Low-pressure real-time
- JSON-driven balance
- Short runs, meta via Queen & traits

## Core Loop

1. **Start:** One built Queen cell in the center.
2. **Expand:** Build Empty cells (cost/time/bee), then convert to Specialised.
3. **Queen → Eggs → Brood → Bees:** Rarity/traits inform Assignments.
4. **Gatherers** run Harvests (trickled resources) and Contracts (items → inventory).
5. **Handle threats, build defense,** and beat the boss before the swarm.

## World & Grid

- 2D, hex flat-topped (axial q,r), TileMap visuals.
- Merging: Adjacent same-type cells form a building group; capacity linear, output = base × (1 + 0.6·(size−1)); max size 7; colored outline.

## Build, Convert, Repair

- **Build Empty Cell:** cost 1 Comb, requires 1 free bee, 10s; Construction trait: −3s → 7s. Must be adjacent to any built cell.
- **Convert Empty → Specialised:** instant (unless noted).
- **Damaged:** blocked tile. Repair → Empty: 2 Comb, 1 bee, 30s; Construction: −3s → 27s.

## Queen, Eggs, Brood, Traits

- Feed Queen → Egg (goes to Inventory)
  - 10 Honey → Common (hatch 10s; 5% bump to Unique)
  - 20 Honey → Unique (hatch 15s; 10% bump to Rare)
  - 30 Honey → Rare (hatch 20s)
- Brood cell (build then insert egg): 1 Comb + 5 Honey, 1 bee, 5s to build → insert egg → hatch (10/15/20s). After hatch: cell becomes Damaged, bee added to roster (unassigned).
- Bee rarities (outline): Common green, Unique blue, Rare purple.
- Traits (examples):
  - Construction: −3s on build/repair tasks.
  - Gather: +% to Harvest trickle rate.
  - (Future: Brewer, Guard, Arcanist, etc.)
- Assignments: Space on a building → Assign panel (bee cards with icon, name, “+N” efficiency).

## Roles & Specialised Cells

- Gatherers: do Harvests (resource trickle) + Contracts (items).
- Wax Workshop (Builders): 2 Pollen → 1 Comb per 5s per bee; cap 2; merge-scales.
- Honey Vat (Brewers): shared batch; cap 3; recipes (bee-count gates):
  - Common: 2× Common → 1 Honey / 5s (≥1 bee)
  - Sweet: 2× Sweet → 2 Honey / 10s (≥2 bees)
  - Rich: 1× Rich → 1 Honey / 15s (≥3 bees)
  - Each extra bee reduces current batch −1s (respects gates).
- Guard Post (Guards): builds Defense Meter over time. Tick 5s → 4s/3s with upgrades; +1/guard/tick and +1/guard per level; cap grows with upgrades; upgrade costs double per level.
- Candle Hall (Arcanists): rituals 60s − 5s/bee (min 20s), roll 3, pay on cast, instant cast.
- Storage: +5 cap per level; L5 max; upgrade cost doubles per level.
- Brood / Damaged: see above.

## Harvests (Gatherers) — Trickle

- Offer shows name, required bees, duration D, totals (e.g., Pollen 50, Nectar 30).
- Start only if enough free Gatherers (and cost if any).
- 5% delay, then even trickle per second across remaining time using float accumulators; spawn “+x” at the field each non-zero tick.
- If storage is full, undelivered amounts keep trying; any left at final tick is wasted.
- On completion, bees free; UI updates.

## Contracts (Items)

- Separate from Harvests.
- Example: “Thistle Flower” — N bees, cost (e.g., 10 Honey, 5 Pollen), 20s, reward item (stacks) to Inventory.
- Multiple can run if you have bees and resources.

## Resources, Items, Storage

- Resources: Honey, Comb, Pollen, NectarCommon/Sweet/Rich, PetalWhite/Pink/Yellow/Red/Blue/Purple, plus item IDs (e.g., ThistleFlower).
- Inventory: holds Eggs (Common/Unique/Rare) and item rewards (stacking).
- Per-resource caps; production pauses on full. (Harvest exception: waste at end.)
- Start values (JSON, editable): Honey 1, Comb 5, Pollen 5, NectarCommon 5; Egg 3 in inventory.

## Threats & Boss (kept from v1)

- One threat active at a time; 5-min warning, then single check vs Defense Meter; Power ×2 each reappearance; fail = loss.
- Boss auto by 45 min; 3 checks 1000/1300/1700 one minute apart; debuffs on failed phases.

## Controls (defaults)

- Arrows move cursor; Space context action; Z back.
- Space on Empty → Radial Build (round buttons; arrows select; Space confirm).
- Space on Building → Assign panel (bee cards; Space assigns).
- Tab / Start → Resources slide-out (name 10/20, icons, live update).
- Harvests/Contracts panels: right slide; Space to start.
- A / LB/L1 toggle Outside⟷Hive.
- HUD always shows: Swarm bar, Defense meter, Active field assignments, Threat warning, Ritual progress.

## Tech & Architecture

- Godot 4.4.1, GDScript, TileMap (hex, flat-top).
- Data-only bees; per-building Timer nodes; JSON configs via ConfigDB.gd.
- Events.gd autoload (signals) → HUD/panels react.
- Merge recomputed locally per edit.

### Repo Skeleton

```
/assets/{sprites,sfx,fonts}/
/data/configs/
  resources.json
  start_values.json
  cells.json
  fields/{wildflower.json,clover.json,lavender.json,orchard.json,herb_garden.json,sunflower.json}
  harvests.json
  contracts.json
  abilities.json
  threats.json
  queen_traits.json
  upgrades.json
  controls.json
/scenes/{Game.tscn,HiveView.tscn,OutsideView.tscn,UI/{Hud.tscn,Panels...}}
/scripts/
  autoload/{ConfigDB.gd,GameState.gd,Events.gd}
  models/{BeeModel.gd,CellModel.gd,FieldModel.gd}
  systems/{HiveSystem.gd,MergeSystem.gd,FieldSystem.gd,ProductionSystem.gd,
           DefenseSystem.gd,ThreatSystem.gd,AbilitySystem.gd,HarvestController.gd,ContractController.gd}
  controllers/{InputController.gd,SelectionController.gd,BuildController.gd,AssignController.gd}
  ui/{BuildRadialMenu.gd,AssignBeePanel.gd,ResourcesPanel.gd,HarvestsPanel.gd,ContractsPanel.gd,InventoryPanel.gd}
```

## Key JSON (concise examples)

### start_values.json

```
{ "start_cells": 1, "start_workers": 0,
  "resources": {"Honey":1,"Comb":5,"Pollen":5,"NectarCommon":5},
  "inventory": {"EggCommon":3}
}
```

### cells.json (excerpt)

```
{
  "Empty": { "build": {"cost":{"Comb":1},"requires_bee":true,"seconds":10,"trait_construction_bonus":3}, "mergeable":false },
  "Brood": { "cost":{"Comb":1,"Honey":5}, "requires_bee":true, "build_seconds":5,
             "hatch_seconds":{"Common":10,"Unique":15,"Rare":20},
             "rarity_bumps":{"CommonToUnique":0.05,"UniqueToRare":0.10},
             "post_hatch":"Damaged", "mergeable":false },
  "Damaged": { "repair":{"cost":{"Comb":2},"requires_bee":true,"seconds":30,"trait_construction_bonus":3},
               "buildable":false,"assignable":false,"mergeable":false },
  "HoneyVat": { ... }, "WaxWorkshop": { ... }, "GuardPost": { ... }, "CandleHall": { ... }, "Storage": { ... }
}
```

### harvests.json

```
{ "offers":[
    {"id":"Harvest_Wildflower","name":"Wildflower Field","required_bees":3,"duration_seconds":100,
     "outputs":{"Pollen":50,"NectarCommon":30}}
  ],
  "tick_seconds":1, "delay_ratio":0.05
}
```

### contracts.json

```
{ "contracts":[
    {"id":"ThistleFlower","name":"Thistle Flower","required_bees":3,"duration_seconds":20,
     "cost":{"Honey":10,"Pollen":5},"reward":{"ThistleFlower":1}}
] }
```

### resources.json

```
{ "base_caps_per_resource": 10,
  "ids":["Honey","Comb","Pollen","NectarCommon","NectarSweet","NectarRich",
         "PetalWhite","PetalPink","PetalYellow","PetalRed","PetalBlue","PetalPurple"] }
```

### items.json

```
{
  "items": [
    { "id":"EggCommon", "name":"Common Egg", "icon":"res://assets/icons/egg_common.svg" },
    { "id":"EggUnique", "name":"Unique Egg", "icon":"res://assets/icons/egg_unique.svg" },
    { "id":"EggRare", "name":"Rare Egg", "icon":"res://assets/icons/egg_rare.svg" },
    { "id":"ThistleFlower", "name":"Thistle Flower", "icon":"res://assets/icons/thistle.svg" }
  ],
  "order":["EggCommon","EggUnique","EggRare","ThistleFlower"]
}
```
