extends Node
class_name HiveSystem

static var _cells: Dictionary = {}
static var _cell_timers: Dictionary = {}
static var _center_cell_id: int = -1
static var _coord_to_id: Dictionary = {}

const EMPTY_TYPE := StringName("Empty")
const BROOD_TYPE := StringName("Brood")
const DAMAGED_TYPE := StringName("Damaged")

static func reset() -> void:
    _cells.clear()
    _cell_timers.clear()
    _center_cell_id = -1
    _coord_to_id.clear()

static func register_cell(cell_id: int, data: Dictionary) -> void:
    var entry: Dictionary = data.duplicate(true)
    entry["cell_id"] = cell_id
    entry["type"] = entry.get("type", "Empty")
    entry["group_id"] = entry.get("group_id", cell_id)
    entry["capacity"] = entry.get("capacity", 0)
    entry["assigned"] = entry.get("assigned", [])
    entry["size"] = entry.get("size", 1)
    entry["efficiency_bonus"] = entry.get("efficiency_bonus", 0)
    entry["metadata"] = entry.get("metadata", {})
    var coord_value: Variant = entry.get("coord", Vector2i.ZERO)
    var coord: Vector2i = Vector2i.ZERO
    if typeof(coord_value) == TYPE_VECTOR2I:
        coord = coord_value
    elif typeof(coord_value) == TYPE_VECTOR2:
        coord = Vector2i(round(coord_value.x), round(coord_value.y))
    entry["coord"] = coord
    _cells[cell_id] = entry
    _coord_to_id[coord] = cell_id

static func set_center_cell(cell_id: int) -> void:
    _center_cell_id = cell_id

static func get_center_cell_id() -> int:
    return _center_cell_id

static func convert_cell_type(cell_id: int, new_type: StringName) -> void:
    if not _cells.has(cell_id):
        return
    var entry: Dictionary = _cells[cell_id]
    _clear_timers(cell_id)
    entry["type"] = String(new_type)
    entry["metadata"] = {}
    if new_type == EMPTY_TYPE or new_type == BROOD_TYPE or new_type == DAMAGED_TYPE:
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

static func set_cell_metadata(cell_id: int, key: String, value: Variant) -> void:
    if not _cells.has(cell_id):
        return
    var entry: Dictionary = _cells[cell_id]
    var meta: Dictionary = {}
    var existing: Variant = entry.get("metadata", {})
    if typeof(existing) == TYPE_DICTIONARY:
        meta = existing.duplicate(true)
    if typeof(value) == TYPE_NIL:
        meta.erase(key)
    elif typeof(value) == TYPE_DICTIONARY and value.is_empty():
        meta.erase(key)
    else:
        meta[String(key)] = value
    entry["metadata"] = meta
    _cells[cell_id] = entry

static func get_cell_type(cell_id: int) -> String:
    return _cells.get(cell_id, {}).get("type", "Empty")

static func get_cell_entry(cell_id: int) -> Dictionary:
    return _cells.get(cell_id, {}).duplicate(true)

static func get_cell_metadata(cell_id: int) -> Dictionary:
    if not _cells.has(cell_id):
        return {}
    var meta: Variant = _cells[cell_id].get("metadata", {})
    if typeof(meta) == TYPE_DICTIONARY:
        return meta.duplicate(true)
    return {}

static func get_cell_coord(cell_id: int) -> Vector2i:
    var entry: Dictionary = _cells.get(cell_id, {})
    if entry.is_empty():
        return Vector2i.ZERO
    var coord_value: Variant = entry.get("coord", Vector2i.ZERO)
    if typeof(coord_value) == TYPE_VECTOR2I:
        return coord_value
    if typeof(coord_value) == TYPE_VECTOR2:
        return Vector2i(round(coord_value.x), round(coord_value.y))
    return Vector2i.ZERO

static func get_cell_id_at_coord(coord: Vector2i) -> int:
    if _coord_to_id.has(coord):
        return int(_coord_to_id[coord])
    return -1

static func get_building_info(cell_id: int) -> Dictionary:
    if not _cells.has(cell_id):
        return {}
    var entry: Dictionary = _cells[cell_id]
    var cell_type: String = entry.get("type", "Empty")
    var cell_type_name: StringName = StringName(cell_type)
    if cell_type_name == EMPTY_TYPE:
        return {}
    if not ConfigDB.is_cell_assignable(cell_type_name):
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

static func attach_timer(cell_id: int, key: String, seconds: float, callback: Callable) -> void:
    if seconds <= 0.0:
        if callback.is_valid():
            callback.call()
        return
    var main_loop: MainLoop = Engine.get_main_loop()
    if main_loop is SceneTree:
        var timer: SceneTreeTimer = (main_loop as SceneTree).create_timer(max(0.0, seconds))
        if timer:
            if not _cell_timers.has(cell_id):
                _cell_timers[cell_id] = {}
            _cell_timers[cell_id][key] = timer
            timer.timeout.connect(func() -> void:
                if _cell_timers.has(cell_id):
                    var dict: Dictionary = _cell_timers[cell_id]
                    dict.erase(key)
                    if dict.is_empty():
                        _cell_timers.erase(cell_id)
                if callback.is_valid():
                    callback.call()
            , CONNECT_ONE_SHOT)
            return
    if callback.is_valid():
        callback.call()

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


static func _clear_timers(cell_id: int) -> void:
    if _cell_timers.has(cell_id):
        _cell_timers.erase(cell_id)


static func set_cell_type(cell_id: int, new_type: StringName) -> void:
    convert_cell_type(cell_id, new_type)
    if typeof(Events) == TYPE_OBJECT:
        Events.cell_converted.emit(cell_id, new_type)
