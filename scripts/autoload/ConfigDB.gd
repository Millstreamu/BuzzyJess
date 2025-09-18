extends Node

const BUILD_ORDER: Array[StringName] = [
    StringName("Brood"),
    StringName("Storage"),
    StringName("HoneyVat"),
    StringName("WaxWorkshop"),
    StringName("CandleHall"),
    StringName("GuardPost"),
    StringName("HerbalistDen")
]

const BUILDING_ASSIGNMENT_DEFAULTS := {
    "Storage": {"capacity": 1, "efficiency": 1},
    "HoneyVat": {"capacity": 2, "efficiency": 2},
    "WaxWorkshop": {"capacity": 1, "efficiency": 1},
    "CandleHall": {"capacity": 2, "efficiency": 3},
    "GuardPost": {"capacity": 1, "efficiency": 1},
    "HerbalistDen": {"capacity": 1, "efficiency": 2}
}

var _cell_defs: Dictionary = {}
var _buildable_ids: Array[StringName] = []
var _resource_defs: Array[Dictionary] = []
var _resource_lookup: Dictionary = {}

func _ready() -> void:
    load_cells()
    load_resources()

func load_cells() -> void:
    _cell_defs.clear()
    _buildable_ids.clear()
    var path: String = "res://data/configs/cells.json"
    if not FileAccess.file_exists(path):
        push_warning("cells.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid cells.json contents")
        return
    _cell_defs = parsed
    for id in BUILD_ORDER:
        if _cell_defs.has(String(id)):
            _buildable_ids.append(id)
    for key in _cell_defs.keys():
        if key == "Empty":
            continue
        var id: StringName = StringName(key)
        if _buildable_ids.has(id):
            continue
        _buildable_ids.append(id)

func load_resources() -> void:
    _resource_defs.clear()
    _resource_lookup.clear()
    var path: String = "res://data/configs/resources.json"
    if not FileAccess.file_exists(path):
        push_warning("resources.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid resources.json contents")
        return
    var list: Variant = parsed.get("resources", [])
    if typeof(list) != TYPE_ARRAY:
        push_warning("Invalid resources.json: expected 'resources' array")
        return
    for entry in list:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = entry.get("id", "")
        if typeof(id_value) != TYPE_STRING:
            continue
        var id: StringName = StringName(String(id_value))
        var def := {
            "id": id,
            "display_name": String(entry.get("display_name", String(id_value))),
            "cap": int(entry.get("cap", 0)),
            "initial": int(entry.get("initial", 0))
        }
        _resource_defs.append(def)
        _resource_lookup[String(id)] = def

func get_buildable_cell_types() -> Array[StringName]:
    return _buildable_ids.duplicate()

func get_cell_cost(cell_type: StringName) -> Dictionary:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var cost: Variant = def.get("cost", {})
    if typeof(cost) == TYPE_DICTIONARY:
        return cost.duplicate(true)
    return {}

func has_cell_type(cell_type: StringName) -> bool:
    return _cell_defs.has(String(cell_type))

func get_base_assignment_capacity(cell_type: StringName) -> int:
    var entry: Dictionary = BUILDING_ASSIGNMENT_DEFAULTS.get(String(cell_type), {})
    return int(entry.get("capacity", 0))

func get_efficiency(building_type: StringName) -> int:
    var entry: Dictionary = BUILDING_ASSIGNMENT_DEFAULTS.get(String(building_type), {})
    return int(entry.get("efficiency", 0))

func get_resource_ids() -> Array[StringName]:
    var ids: Array[StringName] = []
    for def in _resource_defs:
        var id: StringName = def.get("id", StringName(""))
        if id != StringName(""):
            ids.append(id)
    return ids

func get_resource_cap(resource_id: StringName) -> int:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    return int(def.get("cap", 0))

func get_resource_initial(resource_id: StringName) -> int:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    return int(def.get("initial", 0))

func get_resource_display_name(resource_id: StringName) -> String:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    return String(def.get("display_name", String(resource_id)))
