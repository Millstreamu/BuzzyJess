# Configuration Schema (v2)

This document outlines the JSON structures used for configuration files in version 2.

## data/configs/cells.json
- Top-level object keyed by cell type identifier.
- Common properties:
  - `build_cost`: object mapping resource names to required amounts.
  - `per_cell_bee_cap`: integer bee assignment cap (optional).
  - `merge_multiplier_per_extra_cell`: float multiplier applied per additional cell in a complex (optional).
- `WaxWorkshop`:
  - `tick_seconds`: float seconds per production tick.
  - `input_per_tick` / `output_per_tick`: resource maps processed every tick.
  - `adjacency_output_bonus_per_neighbor`: float bonus applied per adjacent allied cell.
  - `trait_bonuses`: object keyed by trait id with `per_bee_mult` and optional `cap`.
- `HoneyVat`:
  - `batch`: object with `input`/`output` resource maps per batch.
  - `batch_seconds_per_complex_size`: object with `base` seconds and `per_extra` additive seconds per extra cell.
  - `local_buffer_per_cell`: integer local storage per cell.
  - `purity`: object describing RJ purity contributions with keys `common`, `threshold`, `candle_hall_bonus_if_any_adjacent`, and `scope`.
- `Storage`:
  - `per_adjacent_bonus`: integer storage increase per adjacent cell.
- `GatheringHut`:
  - `gathering`: object describing offer automation with keys `virtual_bees_per_two_cells`, `auto_pick_smallest_complex`, `tie_breaker`, and `distinct_complexes_required`.
- `GuardPost`:
  - `tick_seconds`: float seconds per defense tick.
  - `base_per_tick`: base defense power generated per tick.
  - `adjacency`: object with caps and `speed_bonus_per_neighbor` multiplier.
- `CandleHall`:
  - `auto_ritual`: object with `enabled`, `interval_seconds`, and `cost` resource map.
  - `adjacency`: object describing interval bonuses and `countable_types` array.
- `Brood`:
  - `hatch_seconds`: float time for larvae to hatch.
  - `ready_requires_manual_hatch`: boolean gating manual hatch.
  - `enclosure`: object listing `block_types` that form an enclosure.
  - `on_enclosure_break`: object describing the `result` state and `egg` outcome.

## data/configs/queens.json
- `tiers`: array of integers representing draft counts per tier (highest to lowest).
- `tier_up_item`: string resource id consumed to tier up.
- `tier_up_costs`: object mapping tier number (as string) to required item count.

## data/configs/queen_cards.json
- `offer_count`: integer number of cards shown on each draft.
- `cards`: array of card objects containing:
  - `id`: unique string identifier.
  - `name`: display name.
  - `mods`: object of modifier keys with numeric values applied when the card is chosen.

## data/configs/offers.json
- `base_slots`: object mapping offer category to default slot counts.
- `per_extra_complex_bonus`: object with additional slots granted per extra complex.
- `harvests_pool` / `item_quests_pool`: arrays of offer templates (empty placeholders for now).
- `weights`: object mapping offer identifiers to their selection weights.

## data/configs/abilities.json
- Placeholder empty object reserved for future ability definitions (keyed by ability id).

## data/configs/traits.json
- `traits`: array of trait objects with:
  - `id`: unique string identifier.
  - `name`: display label.
  - `effects`: object describing trait modifiers; current schema includes `wax_output_bonus_per_assigned_bee` and `wax_output_bonus_cap`.

## data/configs/storage_linked.json
- Top-level object keyed by storage configuration (e.g., `LinkedStorage`).
- Each value maps cell type identifiers to arrays of resource ids they share with the linked storage network.

## data/configs/threats.json
- `global`: object of timing and scaling controls (`warning_seconds`, `min_spawn_gap_seconds`, `power_growth`, `base_power`, `resolve`).
- `list`: array of threat entries each with at least an `id` field.
- `weights`: object mapping threat ids to spawn weights.

## data/configs/boss.json
- `hard_cap_seconds`: integer for forced fail timer.
- `warning_seconds`: integer early warning timer.
- `phases`: array of integers marking phase thresholds.
- `phase_gap_seconds`: integer downtime between phases.
