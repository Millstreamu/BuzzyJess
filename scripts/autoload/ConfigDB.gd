extends Node

const BUILD_ORDER: Array[StringName] = [
    StringName("Brood"),
    StringName("Storage"),
    StringName("HoneyVat"),
    StringName("WaxWorkshop"),
    StringName("CandleHall"),
    StringName("GuardPost"),
    StringName("GatheringHut")
]

const BUILDING_ASSIGNMENT_DEFAULTS := {
    "Storage": {"capacity": 1, "efficiency": 1},
    "HoneyVat": {"capacity": 2, "efficiency": 2},
    "WaxWorkshop": {"capacity": 1, "efficiency": 1},
    "CandleHall": {"capacity": 2, "efficiency": 3},
    "GuardPost": {"capacity": 1, "efficiency": 1},
    "GatheringHut": {"capacity": 1, "efficiency": 2}
}

var _cell_defs: Dictionary = {}
var _buildable_ids: Array[StringName] = []
var _resource_defs: Array[Dictionary] = []
var _resource_lookup: Dictionary = {}
var _harvest_offers: Array[Dictionary] = []
var _harvest_lookup: Dictionary = {}
var _queen_defs: Array[Dictionary] = []
var _threat_defs: Array[Dictionary] = []
var _threat_lookup: Dictionary = {}
var _threat_weights: Dictionary = {}
var _threat_global: Dictionary = {}
var _boss_cfg: Dictionary = {}
var _traits_cfg: Dictionary = {}
var _traits_per_rarity: Dictionary = {}

func _ready() -> void:
    load_cells()
    load_resources()
    load_harvest_offers()
    load_queens()
    load_threats()
    load_boss()
    load_traits()

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

func load_harvest_offers() -> void:
    _harvest_offers.clear()
    _harvest_lookup.clear()
    var path: String = "res://data/configs/harvests.json"
    if not FileAccess.file_exists(path):
        push_warning("harvests.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid harvests.json contents")
        return
    var list: Variant = parsed.get("harvests", [])
    if typeof(list) != TYPE_ARRAY:
        push_warning("Invalid harvests.json: expected 'harvests' array")
        return
    for entry in list:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var offer: Dictionary = {}
        var id_value: Variant = entry.get("id", "")
        if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
            continue
        var id_string: String = String(id_value)
        offer["id"] = StringName(id_string)
        offer["name"] = String(entry.get("name", id_string))
        offer["required_bees"] = int(entry.get("required_bees", 0))
        offer["duration_seconds"] = float(entry.get("duration_seconds", 0))
        offer["cost"] = _parse_resource_amounts(entry.get("cost", {}))
        offer["outputs"] = _parse_resource_amounts(entry.get("outputs", {}))
        _harvest_offers.append(offer)
        _harvest_lookup[id_string] = offer

func load_queens() -> void:
    _queen_defs.clear()
    var path: String = "res://data/configs/queens.json"
    if not FileAccess.file_exists(path):
        push_warning("queens.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid queens.json contents")
        return
    var list_value: Variant = parsed.get("queens", [])
    if typeof(list_value) != TYPE_ARRAY:
        push_warning("Invalid queens.json: expected 'queens' array")
        return
    for entry in list_value:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = entry.get("id", "")
        if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
            continue
        var id_string: String = String(id_value)
        if id_string.is_empty():
            continue
        var queen: Dictionary = {}
        queen["id"] = StringName(id_string)
        queen["name"] = String(entry.get("name", id_string))
        queen["desc"] = String(entry.get("desc", ""))
        var effects: Dictionary = {}
        var effects_value: Variant = entry.get("effects", {})
        if typeof(effects_value) == TYPE_DICTIONARY:
            for key in effects_value.keys():
                var effect_key: String = String(key)
                effects[effect_key] = effects_value.get(key)
        queen["effects"] = effects
        _queen_defs.append(queen)

func load_threats() -> void:
    _threat_defs.clear()
    _threat_lookup.clear()
    _threat_weights.clear()
    _threat_global.clear()
    var path: String = "res://data/configs/threats.json"
    if not FileAccess.file_exists(path):
        push_warning("threats.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid threats.json contents")
        return
    var global_value: Variant = parsed.get("global", {})
    if typeof(global_value) == TYPE_DICTIONARY:
        for key in global_value.keys():
            _threat_global[String(key)] = global_value.get(key)
    var list_value: Variant = parsed.get("list", [])
    if typeof(list_value) == TYPE_ARRAY:
        for entry in list_value:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var id_value: Variant = entry.get("id", "")
            if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
                continue
            var id_string: String = String(id_value)
            if id_string.is_empty():
                continue
            var threat: Dictionary = {}
            threat["id"] = StringName(id_string)
            threat["name"] = String(entry.get("name", id_string))
            _threat_defs.append(threat)
            _threat_lookup[id_string] = threat
    var weights_value: Variant = parsed.get("weights", {})
    if typeof(weights_value) == TYPE_DICTIONARY:
        for key in weights_value.keys():
            var weight_value: Variant = weights_value.get(key, 0)
            if typeof(weight_value) != TYPE_FLOAT and typeof(weight_value) != TYPE_INT:
                continue
            _threat_weights[String(key)] = float(weight_value)

func load_boss() -> void:
    _boss_cfg.clear()
    var path: String = "res://data/configs/boss.json"
    if not FileAccess.file_exists(path):
        push_warning("boss.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid boss.json contents")
        return
    for key in parsed.keys():
        var value: Variant = parsed.get(key)
        if typeof(value) == TYPE_ARRAY:
            var arr: Array = []
            for item in value:
                if typeof(item) == TYPE_FLOAT or typeof(item) == TYPE_INT:
                    arr.append(int(round(float(item))))
            _boss_cfg[String(key)] = arr
        elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
            _boss_cfg[String(key)] = float(value)
        else:
            _boss_cfg[String(key)] = value

func load_traits() -> void:
    _traits_cfg.clear()
    _traits_per_rarity.clear()
    var path: String = "res://data/configs/traits.json"
    if not FileAccess.file_exists(path):
        push_warning("traits.json not found at %s" % path)
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid traits.json contents")
        return
    var parsed_dict: Dictionary = parsed
    _traits_cfg = parsed_dict.duplicate(true)
    var per_rarity_value: Variant = parsed_dict.get("traits_per_rarity", {})
    if typeof(per_rarity_value) == TYPE_DICTIONARY:
        for key in per_rarity_value.keys():
            var count_value: Variant = per_rarity_value.get(key, 0)
            if typeof(count_value) == TYPE_FLOAT or typeof(count_value) == TYPE_INT:
                _traits_per_rarity[String(key)] = int(round(float(count_value)))
    var pools_value: Variant = parsed_dict.get("rarity_pools", {})
    var processed_pools: Dictionary = {}
    if typeof(pools_value) == TYPE_DICTIONARY:
        for key in pools_value.keys():
            var pool_array: Array = []
            var source_value: Variant = pools_value.get(key, [])
            if typeof(source_value) == TYPE_ARRAY:
                for entry in source_value:
                    if typeof(entry) != TYPE_DICTIONARY:
                        continue
                    var id_value: Variant = entry.get("id", "")
                    var id_string: String = String(id_value)
                    if id_string.is_empty():
                        continue
                    var weight_value: Variant = entry.get("weight", 0)
                    if typeof(weight_value) != TYPE_FLOAT and typeof(weight_value) != TYPE_INT:
                        continue
                    var weight: float = max(float(weight_value), 0.0)
                    if weight <= 0.0:
                        continue
                    pool_array.append({
                        "id": StringName(id_string),
                        "weight": weight
                    })
            processed_pools[String(key)] = pool_array
    _traits_cfg["rarity_pools"] = processed_pools

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

func get_cell_flag(cell_type: StringName, key: String, default_value: bool = false) -> bool:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    if def.is_empty():
        return default_value
    var value: Variant = def.get(key, default_value)
    if typeof(value) == TYPE_BOOL:
        return bool(value)
    return default_value

func get_cell_num(cell_type: StringName, key: String, default_value: float = 0.0) -> float:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    if def.is_empty():
        return default_value
    var value: Variant = def.get(key, default_value)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return default_value

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

func get_harvest_offers() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for contract in _harvest_offers:
        list.append(contract.duplicate(true))
    return list

func get_harvest_offer(contract_id: StringName) -> Dictionary:
    var entry: Dictionary = _harvest_lookup.get(String(contract_id), {})
    return entry.duplicate(true)

func get_harvest_outputs(offer_id: StringName) -> Dictionary:
    var offer: Dictionary = get_harvest_offer(offer_id)
    var outputs_value: Variant = offer.get("outputs", {})
    if typeof(outputs_value) == TYPE_DICTIONARY:
        return outputs_value.duplicate(true)
    return {}

func get_queens() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for entry in _queen_defs:
        list.append(entry.duplicate(true))
    return list

func get_threats_cfg() -> Dictionary:
    return {
        "global": _threat_global.duplicate(true),
        "list": _threat_defs.duplicate(true),
        "weights": _threat_weights.duplicate(true)
    }

func get_threat_display_name(id: StringName) -> String:
    var entry: Dictionary = _threat_lookup.get(String(id), {})
    if entry.is_empty():
        return String(id)
    return String(entry.get("name", String(id)))

func get_boss_cfg() -> Dictionary:
    return _boss_cfg.duplicate(true)

func get_traits_cfg() -> Dictionary:
    return _traits_cfg.duplicate(true)

func eggs_get_traits_per_rarity(rarity: StringName) -> int:
    var key: String = String(rarity)
    if key.is_empty():
        key = "Common"
    return int(_traits_per_rarity.get(key, 0))

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
