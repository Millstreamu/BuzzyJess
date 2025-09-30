# Design RevB Alignment Tasks

This checklist captures gaps between the RevB design description and the current data/configuration in the repository. Each item calls out the relevant portion of the design doc and the conflicting implementation details so we can scope the required updates.

## Resource & Item Model

- [ ] Update the design doc (or trim the configs) so that the resource list matches reality. RevB only lists Honey/Comb/Pollen/NectarCommon, but `resources.json` also exposes NectarSweet, NectarRich, and six Petal resources. Decide whether the design should embrace these extra resource types or whether the data should be reduced. (Design doc §"Resources & Items" lines 24–25 vs. `data/configs/resources.json`.)
- [ ] Reconcile the inventory model. RevB states that only Royal Jelly is an inventory item and eggs are hidden, yet `items.json` exposes three egg items plus Thistle Flowers, and `start_values.json` seeds EggCommon inventory. Align the doc and data by either documenting the existing items or changing the configs. (Design doc lines 24–25 vs. `data/configs/items.json` and `data/configs/start_values.json`.)
- [ ] Clarify how Royal Jelly is represented. The design references RJ as an item but there is no explicit item entry in `items.json`. Confirm whether RJ should be added to the data or the doc should instead call it out as a derived value.

## Brood & Egg Flow

- [ ] Add the missing `mixed_neighbors_restrict_chance` tuning that RevB calls out for Brood drafts, or update the design to match the current implementation (which omits the knob). (Design doc lines 49–56 vs. `data/configs/cells.json`.)
- [ ] Harmonize the hatch-timer rules. RevB claims a flat 10s hatch time, while `eggs.json` varies the duration (10/15/20s) by rarity. Decide on the intended behavior and adjust doc and/or configs accordingly. (Design doc line 41 vs. `data/configs/eggs.json`.)
- [ ] Document or remove the queen egg feeding & rarity bump systems present in `eggs.json`, which are absent from the design description. (Design doc lines 37–49 vs. `data/configs/eggs.json`.)

## Abilities & Candle Halls

- [ ] Populate `abilities.json` with the single-use effects that Candle Halls should grant, or revise RevB to explain that the ability list is TBD. The current data file is empty despite the design describing concrete examples. (Design doc lines 112–120 vs. `data/configs/abilities.json`.)
- [ ] Ensure the Candle Hall interval bonus semantics are explicitly documented. The design says "ritual interval −5s" but the data field is named `hall_interval_bonus_seconds` without indicating direction. Update the wording/code comments for clarity if needed. (Design doc lines 112–114 vs. `data/configs/cells.json`.)

## Miscellaneous Alignment

- [ ] Verify whether Guard Post production should be floored per tick as described. The config only exposes a speed bonus multiplier, so either implementation or documentation should clarify the rounding behavior. (Design doc lines 104–105 vs. `data/configs/cells.json`.)
- [ ] Audit UI/UX assumptions such as the Abilities panel and egg counter to make sure matching scenes/UI assets exist; the design references them but the current data and scenes may not. Create follow-up tasks once the actual UI implementation is reviewed.

---

Once decisions are made for each checklist item, update `docs/Design_RevB.md` and/or the relevant configs so the two sources tell the same story.
