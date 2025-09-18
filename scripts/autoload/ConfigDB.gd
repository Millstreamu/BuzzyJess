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

func _ready() -> void:
    load_cells()

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
