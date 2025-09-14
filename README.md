Bee Hive Management — Design Doc v1.0 (Godot 4.4.1 / GDScript / 2D)
1) Concept & Pillars

Pitch: Calm, controller-first, real-time hive builder roguelite. Assign bees → grow hex comb → convert resources → survive threats → defeat boss before swarm.

Pillars: Readability • Low-pressure real time • Controller-first UX • Data-driven balance (JSON) • Short runs, meta-progression via Queen traits.

2) Core Loop

Swarm bar: +1 per new bee; threshold 100 ends run.

Goal: Power up hive and win boss (3 checks: 1000/1300/1700). 5-min warning; hard cap 45 min.

Carryover: Queen only (traits persist). Workers traitless.

3) Views & Controls

Views: Outside Map (fixed, fields) ⟷ Hive (flat-topped hex TileMap). Toggle: A / LB-L1.

Keyboard: Arrows move • Space confirm • Z back • X Build • C Assign • D Ability • Tab info tab.

Gamepad: D-pad move • A confirm • B back • X Build • Y Assign • RB Ability • LB Toggle • Start info tab.

HUD (always): Swarm bar • Defense meter • Active field assignments • Threat warning timer • Ritual progress. (Others on info tab.)

4) Bees & Assignment

Bees: Data-only entities (no nodes). Max ~50.

Assign individually to fields/cells; Auto-fill (no per-bee traits).

New bee: Place Brood (1 Comb + 1 Honey), instant egg, hatch 10s, cell reverts to Empty. +1 swarm point.

5) Cells (instant build) & Merging

Types: Brood (non-merge), Storage, Honey Vat, Wax Workshop, Candle Hall, Guard Post, Herbalist Den.

Merging: Adjacent (edge) same-type cells form a building group (max size 7).

Capacity: linear = base × size.

Output: diminishing = base × (1 + 0.6·(size−1)).

Border: Line2D color/thickness preset.

Storage: +5 cap (L1), +5 each level, L5 max; upgrades cost double per level.

Honey Vat (cap 3): shared single batch; −1s per extra bee; gating by bee count:

Common: need ≥1 bee, 2→1 Honey in 5s

Sweet: need ≥2 bees, 2→2 in 10s

Rich: need ≥3 bees, 1→1 in 15s

Wax Workshop (Builders): cap 2; 2 Pollen → 1 Comb / 5s / bee (linear).

Candle Hall (Arcanists): cap 5; ritual 60s − 5s/bee (min 20s); roll 3; pay on cast; casts immediately.

Guard Post (Guards): cap 5; Defense Meter gen +1/guard/tick; tick 5s, upgrades to 4s/3s; per level also +1 gen/guard; upgrade cost doubles (base: 1 Comb + 1 Honey + 1 Red Petal).

Herbalist Den: cap 3; contracts timer-generated; base 20s (≥3 bees), −3s per extra bee, floor 10s; start cost 10 Honey + 5 Pollen; always succeed, chance bonus; rewards TBD.

6) Outside Fields (fixed map)

Map: 30 tiles → Wildflower×6, Clover×6, Lavender×4, Orchard×4, Herb Garden×4, Sunflower×6.

Model: Always-on; depletion pools (max 500, recharge +30/min each); assignment order payout when short (rule B).

Yields per Farmer per 5s:

Wildflower / Clover: Common 1, Sweet 1, Pollen 1, Petal Yellow 1, White 1 (max workers 100).

Lavender: Sweet 2, Rich 1, Petal Purple 1 (max 50).

Orchard: Rich 2, Sweet 1, Petal White 1, Pink 1 (max 40).

Urban Herb Garden: Common 1, Sweet 1, Pollen 1, Petal Red 1, Blue 1 (max 30).

Sunflower: Pollen 3, Common 1, Petal Yellow 2 (max 60).

7) Threats & Boss

Threats (global): sequential, one at a time. Base Power 10, ×2 each reappearance; 5-min warning, then single check vs Defense Meter; min gap 3 min; fail = immediate loss.

Defense Meter: +1/guard/tick; no cap, no decay, carryover; upgrades increase gen and reduce tick.

Boss: auto ≤ 45 min; 3 checks, 1-min apart: 1000 → 1300 → 1700 (JSON-editable). Each failed phase applies a debuff (TBD).

8) Economy & Storage

Resources: Honey, Comb, Pollen, NectarCommon, NectarSweet, NectarRich, PetalWhite, PetalPink, PetalYellow, PetalRed, PetalBlue, PetalPurple.

Caps: Per-resource caps; production pauses on full.

Start: Cells=10 (all Empty), Workers=5; resources: Honey1, Comb5, Pollen5, NectarCommon5, others 0.

Build Cell: 10 Comb, instant, must be adjacent.

9) Abilities (Arcanist examples — cast on pick)

Refill a chosen field +50% pools.

−20% next threat Power.

+10% worker speed (all timers) for 60s.

If next threat is Bear: +10% Defense Meter gen during its warning.

Next 10 Honey produced become Rich Honey.

Next bee produced works +5% faster.
(All costs/cooldowns set per option; rolled via ritual; editable JSON.)

10) Save/Meta

3 save slots. Persist: Queen library (traits), unlocked trait pool, settings, best score, run stats.

Coding Spec (Godot/GDScript)
Autoloads

/scripts/autoload/ConfigDB.gd

Loads /data/configs/**/*.json on boot; hot-reload function.

Accessors: get_cell_cfg(type), get_field_cfg(id), get_threats(), get_upgrades(), get_controls(), get_swarm_cfg(), etc.

/scripts/autoload/GameState.gd

Run state (resources, caps, workers, swarm points, timers, boss).

APIs: add_resource(id, amt), spend(cost_dict) -> bool, add_bee(), inc_swarm(n), start_threat(id), resolve_threat(), etc.

/scripts/autoload/Events.gd (signals hub)

Signals: swarm_progress_changed(int), resources_changed(Dictionary), cell_built(int,StringName), building_merged(int,StringName,int), threat_warning_started(StringName,int), threat_resolved(StringName,bool), boss_phase_started(int,int), ritual_ready(), ritual_cast(StringName), defense_meter_changed(int).

Scenes

/scenes/Game.tscn (root): holds sub-nodes HiveView, OutsideView, Hud, Menus.

/scenes/HiveView.tscn: TileMap (hex flat-topped), selection cursor, Line2D borders.

/scenes/OutsideView.tscn: field grid & assignment UI.

/scenes/UI/Hud.tscn: bars and compact indicators. InfoTab slides in/out.

Systems (scripts)

HiveSystem.gd: build/convert cells, merging (BFS over neighbors), capacity/output math, hatch handling.

FieldSystem.gd: per-field Timer nodes; assignment order payout (rule B); pools (max/recharge).

ThreatSystem.gd: schedule next threat (global weights), warning timer, resolve check, power scaling ×2, boss phases.

AbilitySystem.gd: ritual queue, rolling 3 options, costs on cast, apply effects.

MergeSystem.gd: recompute connected groups only for touched cells (BFS/union-find); emit border updates.

DefenseSystem.gd: Guard Post timers (per building); meter += gen; upgrades modify tick and gen.

Controllers

InputController.gd: map keys/pad to actions.

SelectionController.gd: cursor on TileMap; focus & interact.

BuildController.gd: open build menu, validate adjacency, apply costs.

AssignController.gd: open assign menu, auto-fill assignment to targets.

Data Models

BeeModel.gd: { id:int, role:StringName|null, location:{type:"cell"/"field", id:int} }

CellModel.gd: { id:int, type:"Empty"/Type, q:int, r:int, level:int, group_id:int|null, timers:{...} }

FieldModel.gd: { id:StringName, assigned:Array[int], pools:Dictionary, timers:{harvest:Timer} }

Determinism & Timers

Per-building Timer nodes (you chose A). Each job has its own Timer child; restart on changes.

All numbers read from JSON; no magic numbers in logic.

Data (JSON) — keys & minimal schemas
/data/configs/resources.json
{
  "base_caps_per_resource": 10,
  "ids": ["Honey","Comb","Pollen","NectarCommon","NectarSweet","NectarRich",
          "PetalWhite","PetalPink","PetalYellow","PetalRed","PetalBlue","PetalPurple"]
}

/data/configs/start_values.json
{
  "start_cells": 10,
  "start_workers": 5,
  "resources": {"Honey":1,"Comb":5,"Pollen":5,"NectarCommon":5}
}

/data/configs/swarm.json
{ "swarm_points_per_bee": 1, "threshold": 100, "run_hardcap_seconds": 2700 }

/data/configs/cells.json  // excerpt
{
  "Brood": {"cost":{"Comb":1,"Honey":1},"hatch_seconds":10,"reverts_to":"Empty","mergeable":false},
  "Storage":{"cost":{"Comb":1},"base_capacity":5,"max_level":5,
    "upgrade":{"base":{"Comb":1,"Honey":1},"scale":"pow2","per_level_capacity":5},"mergeable":true},
  "HoneyVat":{"cost":{"Comb":1,"NectarCommon":1},"cap":3,"mergeable":true,
    "recipes":{
      "Common":{"need_bees":1,"in":{"NectarCommon":2},"out":{"Honey":1},"seconds":5},
      "Sweet":{"need_bees":2,"in":{"NectarSweet":2},"out":{"Honey":2},"seconds":10},
      "Rich":{"need_bees":3,"in":{"NectarRich":1},"out":{"Honey":1},"seconds":15}
    },
    "shared_batch_speed_bonus_per_extra_bee_seconds":1
  },
  "WaxWorkshop":{"cost":{"Pollen":1,"NectarCommon":1},"cap":2,"mergeable":true,
    "rate":{"in":{"Pollen":2},"out":{"Comb":1},"seconds":5}},
  "CandleHall":{"cost":{"Comb":1,"Honey":1,"Pollen":1},"cap":5,"mergeable":true,
    "ritual":{"base_seconds":60,"per_bee_reduction":5,"floor_seconds":20,"pay_on_cast":true}},
  "GuardPost":{"cost":{"Comb":1,"Honey":1},"upgrade_base_cost":{"Comb":1,"Honey":1,"PetalRed":1},
    "cap_base":5,"tick_seconds":[5,4,3],"gen_per_guard_per_level":[1,2,3],"mergeable":true},
  "HerbalistDen":{"cost":{"Comb":1,"Honey":1,"Pollen":1},"cap_base":3,"mergeable":true,
    "contract":{"base_seconds":20,"min_bees":3,"per_extra_bee_reduction":3,"floor_seconds":10,
                "start_cost":{"Honey":10,"Pollen":5}}}
}

/data/configs/fields/wildflower.json
{
  "max_workers":100,
  "yield_per_farmer_per_5s":{"NectarCommon":1,"NectarSweet":1,"Pollen":1,"PetalYellow":1,"PetalWhite":1},
  "pools":{"NectarCommon":{"max":500,"recharge_per_min":30}, "NectarSweet":{"max":500,"recharge_per_min":30},
           "Pollen":{"max":500,"recharge_per_min":30},"PetalYellow":{"max":500,"recharge_per_min":30},
           "PetalWhite":{"max":500,"recharge_per_min":30}},
  "payout_rule":"assignment_order"
}

/data/configs/threats.json
{
  "global":{"base_power":10,"power_growth":"x2","warning_seconds":300,"min_spawn_gap_seconds":180,"resolve":"single_check"},
  "list":[{"id":"Bear"},{"id":"WaspSwarm"},{"id":"Storm"},{"id":"Mites"},{"id":"RobberBees"}]
}


(Also include abilities.json, queen_traits.json, upgrades.json, controls.json with your mappings.)

Repo Structure (GitHub)
/assets/{sprites,sfx,fonts}/
/data/configs/
  resources.json
  start_values.json
  swarm.json
  controls.json
  cells.json
  fields/{wildflower.json,clover.json,lavender.json,orchard.json,herb_garden.json,sunflower.json}
  threats.json
  abilities.json
  queen_traits.json
  upgrades.json
/scenes/{Game.tscn,HiveView.tscn,OutsideView.tscn,UI/{Hud.tscn,Menus.tscn}}
/scripts/
  autoload/{GameState.gd,ConfigDB.gd,Events.gd}
  models/{BeeModel.gd,CellModel.gd,FieldModel.gd}
  systems/{HiveSystem.gd,FieldSystem.gd,ThreatSystem.gd,AbilitySystem.gd,MergeSystem.gd,DefenseSystem.gd}
  controllers/{InputController.gd,SelectionController.gd,BuildController.gd,AssignController.gd}
  ui/{Hud.gd,Menus.gd}
