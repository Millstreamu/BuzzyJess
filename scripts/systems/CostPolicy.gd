# -----------------------------------------------------------------------------
# File: scripts/systems/CostPolicy.gd
# Purpose: Shared helpers for checking and spending hive construction costs
# Depends: ConfigDB, GameState
# Notes: Avoids duplicating can_spend → spend logic across systems
# -----------------------------------------------------------------------------

## CostPolicy
## Wraps common cost calculations and guarded spend helpers.
extends RefCounted
class_name CostPolicy

static func get_empty_build_cost() -> Dictionary:
    var task_cfg: Dictionary = ConfigDB.get_cell_build_task(StringName("Empty"))
    var cost_value: Variant = task_cfg.get("cost", {})
    if typeof(cost_value) == TYPE_DICTIONARY:
        return cost_value.duplicate(true)
    return {}

## Returns true when the given cost dictionary is affordable.
static func can_afford(cost: Dictionary) -> bool:
    if cost.is_empty():
        return true
    return GameState.can_spend(cost)

## Attempts to spend the supplied cost after verifying affordability.
static func try_charge(cost: Dictionary) -> bool:
    if cost.is_empty():
        return true
    if not GameState.can_spend(cost):
        return false
    return GameState.spend(cost)

static func charge_for_empty_build() -> bool:
    return try_charge(get_empty_build_cost())

static func get_conversion_cost(cell_type: StringName) -> Dictionary:
    var cost: Dictionary = ConfigDB.get_cell_cost(cell_type)
    if cost.is_empty():
        return {}
    return cost.duplicate(true)

static func charge_for_conversion(cell_type: StringName) -> bool:
    return try_charge(get_conversion_cost(cell_type))
