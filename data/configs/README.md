# Configuration Overview

All gameplay data lives in this folder as pure JSON files. Godot does not allow
comments inside JSON, so this README documents the important keys and expected
shapes.

## cells.json
- `Empty`, `Storage`, etc: Top-level objects keyed by cell type.
- Each definition can include:
  - `cost`: `{ "ResourceId": amount }` required to convert/build.
  - `build`: `{ "seconds": float, "trait_construction_bonus": float, "cost": {...} }` for
    WorkerTasks.
  - `repair`: Similar shape to `build` but used for damaged cells.

## resources.json
- `base_caps_per_resource`: Default cap applied to every resource entry.
- `ids`: Array of resource identifiers. Each entry may be prettified by
  `ConfigDB.RESOURCE_NAME_OVERRIDES`.

## start_values.json
- `start_cells`, `start_workers`: Initial counts.
- `start_resources`: `{ "ResourceId": amount }`.
- `start_inventory`: `{ "ItemId": amount }` for the opening cache.

## offers.json
- `harvests_pool` / `item_quests_pool`: Arrays of offer entries with `id`,
  `name`, `cost`, and either `outputs` or `reward`.
- `weights`: Per-kind weight dictionaries used for random selection.
- `slots`: Integer counts for simultaneous offers.
- `tick_seconds`, `delay_ratio`: Timing knobs for offer refreshes.

## queens.json
- `queens`: Array of objects with `id`, `name`, `desc`, and optional `effects`
  dictionary.

## threats.json
- `global`: Default fields applied to every threat.
- `list`: Array of threats with `id`, `name`, and extra metadata consumed by
  `ThreatSystem`.
- `weights`: Dictionary mapping threat `id` to spawn weight.

## boss.json
- `phases`: Array of integers for power per phase.
- `phase_gap_seconds`: Seconds of breathing room between phases.
- `warning_seconds`: Lead time before the boss encounter begins.

## traits.json
- `traits`: Array of trait definitions with `id`, `name`, `desc`, and effect
  metadata.
- `rarity_pools`: `{ "Rarity": [{ "id": traitId, "weight": float }] }`.
- `traits_per_rarity`: `{ "Rarity": count }` used when rolling new bees.
- `defaults`: Fallback trait weights per rarity.

## eggs.json
- `feed_costs`: `{ "Tier": { "ResourceId": amount } }` spend tables for
  Queen feeding.
- `hatch_seconds`: `{ "Tier": float }` incubation times.
- `bump_probs`: `{ "Tier": float }` probability of raising a tier.
- `rarity_visuals`: `{ "Rarity": { "color": "#rrggbb" } }` styling hints.
- `traits_per_rarity`: `{ "Rarity": count }` overrides for egg generation.

## items.json
- `items`: Array of objects with `id`, `name`, and `icon` path.
- `order`: Optional array that controls display ordering in `InventoryPanel`.

## abilities.json
- `max_list`: Integer maximum number of held abilities.
- `ritual`: `{ "seconds": float, "comb_cost": int }` describing the ritual.
- `pool`: Array of ability definitions with `id`, `name`, `desc`, `weight`,
  `cost` (`resources`/`items`), and `effect` payloads.

## contracts.json / harvests.json
- Follow the same shape as their counterparts in `offers.json` for per-offer
  configuration.
