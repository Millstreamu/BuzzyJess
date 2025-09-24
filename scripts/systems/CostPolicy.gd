extends RefCounted
class_name CostPolicy

static func get_empty_build_cost() -> Dictionary:
    var task_cfg: Dictionary = ConfigDB.get_cell_build_task(StringName("Empty"))
    var cost_value: Variant = task_cfg.get("cost", {})
    if typeof(cost_value) == TYPE_DICTIONARY:
        return cost_value.duplicate(true)
    return {}

static func charge_for_empty_build() -> bool:
    var cost: Dictionary = get_empty_build_cost()
    if cost.is_empty():
        return true
    return GameState.spend(cost)

static func get_conversion_cost(cell_type: StringName) -> Dictionary:
    var cost: Dictionary = ConfigDB.get_cell_cost(cell_type)
    if cost.is_empty():
        return {}
    return cost.duplicate(true)

static func charge_for_conversion(cell_type: StringName) -> bool:
    var cost: Dictionary = get_conversion_cost(cell_type)
    if cost.is_empty():
        return true
    return GameState.spend(cost)
