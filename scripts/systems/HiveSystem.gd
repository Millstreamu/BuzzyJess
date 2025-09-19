extends Node
class_name HiveSystem

static var _cells: Dictionary = {}

static func reset() -> void:
    _cells.clear()

static func register_cell(cell_id: int, data: Dictionary) -> void:
    var entry: Dictionary = data.duplicate(true)
    entry["cell_id"] = cell_id
    entry["type"] = entry.get("type", "Empty")
    entry["group_id"] = entry.get("group_id", cell_id)
    entry["capacity"] = entry.get("capacity", 0)
    entry["assigned"] = entry.get("assigned", [])
    entry["size"] = entry.get("size", 1)
    entry["efficiency_bonus"] = entry.get("efficiency_bonus", 0)
    _cells[cell_id] = entry

static func convert_cell_type(cell_id: int, new_type: StringName) -> void:
    if not _cells.has(cell_id):
        return
    var entry: Dictionary = _cells[cell_id]
    entry["type"] = String(new_type)
    if new_type == StringName("Empty") or new_type == StringName("Brood"):
        _clear_assignments(entry)
        entry["group_id"] = cell_id
        entry["capacity"] = 0
        entry["efficiency_bonus"] = 0
    else:
        entry["group_id"] = cell_id
        var base_capacity: int = ConfigDB.get_base_assignment_capacity(new_type)
        entry["capacity"] = base_capacity * entry.get("size", 1)
        entry["assigned"] = []
        entry["efficiency_bonus"] = 0
    _cells[cell_id] = entry

static func get_cell_type(cell_id: int) -> String:
    return _cells.get(cell_id, {}).get("type", "Empty")

static func get_cell_entry(cell_id: int) -> Dictionary:
    return _cells.get(cell_id, {}).duplicate(true)

static func get_building_info(cell_id: int) -> Dictionary:
    if not _cells.has(cell_id):
        return {}
    var entry: Dictionary = _cells[cell_id]
    var cell_type: String = entry.get("type", "Empty")
    if cell_type == "Empty":
        return {}
    return {
        "cell_id": cell_id,
        "type": cell_type,
        "group_id": entry.get("group_id", cell_id),
        "capacity": entry.get("capacity", 0),
        "assigned": entry.get("assigned", []),
        "efficiency_bonus": entry.get("efficiency_bonus", 0),
        "size": entry.get("size", 1)
    }

static func get_cells() -> Dictionary:
    return _cells.duplicate(true)

static func has_capacity(group_id: int) -> bool:
    var info: Dictionary = _get_group_entry(group_id)
    if info.is_empty():
        return false
    var assigned: Array = info.get("assigned", [])
    var capacity: int = info.get("capacity", 0)
    return assigned.size() < capacity

static func assign_bee_to_group(group_id: int, bee_id: int, efficiency: int, icon: Texture2D) -> void:
    var info: Dictionary = _get_group_entry(group_id)
    if info.is_empty():
        return
    var assigned: Array = info.get("assigned", [])
    for existing in assigned:
        if typeof(existing) == TYPE_DICTIONARY and existing.get("bee_id", -1) == bee_id:
            return
    var entry := {
        "bee_id": bee_id,
        "efficiency": efficiency,
        "icon": icon
    }
    assigned.append(entry)
    info["assigned"] = assigned
    info["efficiency_bonus"] = info.get("efficiency_bonus", 0) + efficiency
    _update_group_entry(group_id, info)

static func get_cell_assigned_bees(cell_id: int) -> Array:
    if not _cells.has(cell_id):
        return []
    return _cells[cell_id].get("assigned", [])

static func get_cell_bee_icons(cell_id: int) -> Array:
    var assigned: Array = get_cell_assigned_bees(cell_id)
    var icons: Array = []
    for data in assigned:
        if typeof(data) == TYPE_DICTIONARY and data.has("icon") and data.icon != null:
            icons.append(data.icon)
    return icons

static func _get_group_entry(group_id: int) -> Dictionary:
    for cell_id in _cells.keys():
        var entry: Dictionary = _cells[cell_id]
        if entry.get("group_id", cell_id) == group_id:
            return entry
    return {}

static func _update_group_entry(group_id: int, updated: Dictionary) -> void:
    for cell_id in _cells.keys():
        var entry: Dictionary = _cells[cell_id]
        if entry.get("group_id", cell_id) == group_id:
            var copy: Dictionary = updated.duplicate(true)
            copy["cell_id"] = cell_id
            _cells[cell_id] = copy

static func _clear_assignments(entry: Dictionary) -> void:
    var assigned: Array = entry.get("assigned", [])
    for data in assigned:
        if typeof(data) == TYPE_DICTIONARY:
            var bee_id: int = data.get("bee_id", -1)
            if bee_id != -1:
                GameState.unassign_bee(bee_id)
    entry["assigned"] = []
