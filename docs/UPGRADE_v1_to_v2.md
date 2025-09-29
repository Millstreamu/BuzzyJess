# Upgrade Guide: v1 to v2

## Breaking changes
- Configuration schema bumped to version 2 (`data/schema_version.json`) to match the Rev B design.
- Cell production, storage, and gathering rules rely on new per-structure keys (bee caps, adjacency bonuses, ritual automation).
- Threat and boss pacing now reference new timing tables; previous saves expecting v1 timers will not align.

## Renamed/Removed JSON keys
- Queen progression switched to tier arrays (`tiers`, `tier_up_item`, `tier_up_costs`) instead of the v1 stage objects.
- Queen card offers moved to `data/configs/queen_cards.json`; legacy inline definitions should be removed.
- Linked storage routing now uses `data/configs/storage_linked.json` with resource lists per producer instead of implicit behaviour.

## Save compatibility
- Existing v1 saves are not compatible because core config payloads changed shape and the schema version advanced.
- Migrate by starting a fresh save or writing a one-time conversion that maps old progression fields to the new tiered schema.
