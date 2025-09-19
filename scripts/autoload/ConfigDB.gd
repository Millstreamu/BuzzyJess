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
var _herbalist_contracts: Array[Dictionary] = []
var _herbalist_contract_lookup: Dictionary = {}

func _ready() -> void:
    load_cells()
    load_resources()
    load_herbalist_contracts()

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
        if not _cell_defs.has(String(id)):
            continue
        var def: Dictionary = _cell_defs.get(String(id), {})
        if _is_buildable(def):
            _buildable_ids.append(id)
    for key in _cell_defs.keys():
        if key == "Empty":
            continue
        var id: StringName = StringName(key)
        if _buildable_ids.has(id):
            continue
        var def: Dictionary = _cell_defs.get(key, {})
        if not _is_buildable(def):
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
            "initial": int(entry.get("initial", 0)),
            "short_name": String(entry.get("short_name", String(entry.get("display_name", String(id_value)))))
        }
        _resource_defs.append(def)
        _resource_lookup[String(id)] = def

func load_herbalist_contracts() -> void:
    _herbalist_contracts.clear()
    _herbalist_contract_lookup.clear()
    var path: String = "res://data/configs/herbalist_contracts.json"
    if not FileAccess.file_exists(path):
        push_warning("herbalist_contracts.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid herbalist_contracts.json contents")
        return
    var list: Variant = parsed.get("contracts", [])
    if typeof(list) != TYPE_ARRAY:
        push_warning("Invalid herbalist_contracts.json: expected 'contracts' array")
        return
    for entry in list:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var contract: Dictionary = {}
        var id_value: Variant = entry.get("id", "")
        if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
            continue
        var id_string: String = String(id_value)
        contract["id"] = StringName(id_string)
        contract["name"] = String(entry.get("name", id_string))
        contract["required_bees"] = int(entry.get("required_bees", 0))
        contract["duration_seconds"] = float(entry.get("duration_seconds", 0))
        var cost_value: Variant = entry.get("cost", {})
        contract["cost"] = _parse_resource_amounts(cost_value)
        var reward_value: Variant = entry.get("reward", {})
        contract["reward"] = _parse_resource_amounts(reward_value)
        contract["weight"] = float(entry.get("weight", 1.0))
        _herbalist_contracts.append(contract)
        _herbalist_contract_lookup[id_string] = contract

func get_buildable_cell_types() -> Array[StringName]:
    return _buildable_ids.duplicate()

func get_cell_cost(cell_type: StringName) -> Dictionary:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var cost: Variant = def.get("cost", {})
    if typeof(cost) == TYPE_DICTIONARY:
        return cost.duplicate(true)
    return {}

func get_cell_tick_seconds(cell_type: StringName) -> float:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var tick_value: Variant = def.get("tick_seconds", 0.0)
    if typeof(tick_value) == TYPE_FLOAT or typeof(tick_value) == TYPE_INT:
        return float(tick_value)
    return 0.0

func get_cell_production(cell_type: StringName) -> Dictionary:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var produces: Variant = def.get("produces", {})
    if typeof(produces) != TYPE_DICTIONARY:
        return {}
    var result: Dictionary = {}
    for key in produces.keys():
        var amount: Variant = produces[key]
        if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
            result[StringName(String(key))] = float(amount)
    return result

func has_cell_type(cell_type: StringName) -> bool:
    return _cell_defs.has(String(cell_type))

func is_cell_buildable(cell_type: StringName) -> bool:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    return _is_buildable(def)

func is_cell_assignable(cell_type: StringName) -> bool:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    if def.is_empty():
        return true
    var assignable: Variant = def.get("assignable", true)
    if typeof(assignable) == TYPE_BOOL:
        return assignable
    return true

func get_cell_hatch_seconds(cell_type: StringName) -> float:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("hatch_seconds", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return 0.0

func get_cell_post_hatch_type(cell_type: StringName) -> StringName:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("post_hatch_type", "")
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        return StringName(String(value))
    return StringName("")

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

func get_resource_short_name(resource_id: StringName) -> String:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    if def.has("short_name"):
        return String(def.get("short_name", ""))
    return get_resource_display_name(resource_id)

func get_herbalist_contracts() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for contract in _herbalist_contracts:
        list.append(contract.duplicate(true))
    return list

func get_herbalist_contract(contract_id: StringName) -> Dictionary:
    var entry: Dictionary = _herbalist_contract_lookup.get(String(contract_id), {})
    return entry.duplicate(true)

func get_herbalist_reward(contract_id: StringName) -> Dictionary:
    var contract: Dictionary = get_herbalist_contract(contract_id)
    var reward_value: Variant = contract.get("reward", {})
    if typeof(reward_value) == TYPE_DICTIONARY:
        return reward_value.duplicate(true)
    return {}

func _is_buildable(def: Dictionary) -> bool:
    if def.is_empty():
        return true
    var value: Variant = def.get("buildable", true)
    if typeof(value) == TYPE_BOOL:
        return value
    return true

func _parse_resource_amounts(value: Variant) -> Dictionary:
    if typeof(value) != TYPE_DICTIONARY:
        return {}
    var result: Dictionary = {}
    for key in value.keys():
        var amount: Variant = value.get(key, 0)
        if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
            result[StringName(String(key))] = int(round(amount))
    return result
