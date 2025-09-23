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
var _egg_feed_costs: Dictionary = {}
var _egg_hatch_seconds: Dictionary = {}
var _egg_bump_probs: Dictionary = {}
var _egg_rarity_visuals: Dictionary = {}
var _egg_traits_per_rarity: Dictionary = {}
var _item_ids: Array[StringName] = []

func _ready() -> void:
    load_cells()
    load_resources()
    load_harvest_offers()
    load_queens()
    load_threats()
    load_boss()
    load_traits()
    load_eggs()
    load_items()

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
    var path: String = "res://data/configs/traits.json"
    if not FileAccess.file_exists(path):
        push_warning("traits.json not found at %s" % path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid traits.json contents")
        return
    var traits_list: Array[Dictionary] = []
    var traits_value: Variant = parsed.get("traits", [])
    if typeof(traits_value) == TYPE_ARRAY:
        for entry in traits_value:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var id_value: Variant = entry.get("id", "")
            if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
                continue
            var id_string: String = String(id_value)
            if id_string.is_empty():
                continue
            var trait_entry: Dictionary = {}
            trait_entry["id"] = StringName(id_string)
            trait_entry["name"] = String(entry.get("name", id_string))
            trait_entry["desc"] = String(entry.get("desc", ""))
            var effects: Dictionary = {}
            var effects_value: Variant = entry.get("effects", {})
            if typeof(effects_value) == TYPE_DICTIONARY:
                for key in effects_value.keys():
                    effects[StringName(String(key))] = effects_value.get(key)
            trait_entry["effects"] = effects
            traits_list.append(trait_entry)
    var rarity_pools: Dictionary = {}
    var pools_value: Variant = parsed.get("rarity_pools", {})
    if typeof(pools_value) == TYPE_DICTIONARY:
        for key in pools_value.keys():
            var pool_id: String = String(key)
            var pool_entries: Array[Dictionary] = []
            var pool_value: Variant = pools_value.get(key, [])
            if typeof(pool_value) != TYPE_ARRAY:
                continue
            for item in pool_value:
                if typeof(item) != TYPE_DICTIONARY:
                    continue
                var trait_id_value: Variant = item.get("id", "")
                if typeof(trait_id_value) != TYPE_STRING and typeof(trait_id_value) != TYPE_STRING_NAME:
                    continue
                var pool_entry: Dictionary = {}
                pool_entry["id"] = StringName(String(trait_id_value))
                var weight_value: Variant = item.get("weight", 0.0)
                if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
                    pool_entry["weight"] = float(weight_value)
                else:
                    pool_entry["weight"] = 0.0
                pool_entries.append(pool_entry)
            rarity_pools[StringName(pool_id)] = pool_entries
    var counts: Dictionary = {}
    var counts_value: Variant = parsed.get("traits_per_rarity", {})
    if typeof(counts_value) == TYPE_DICTIONARY:
        for key in counts_value.keys():
            var amount: Variant = counts_value.get(key, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                counts[StringName(String(key))] = int(round(float(amount)))
    var defaults: Dictionary = {}
    var defaults_value: Variant = parsed.get("defaults", {})
    if typeof(defaults_value) == TYPE_DICTIONARY:
        for key in defaults_value.keys():
            defaults[StringName(String(key))] = defaults_value.get(key)
    _traits_cfg = {
        "traits": traits_list,
        "rarity_pools": rarity_pools,
        "traits_per_rarity": counts,
        "defaults": defaults
    }

func load_eggs() -> void:
    _egg_feed_costs.clear()
    _egg_hatch_seconds.clear()
    _egg_bump_probs.clear()
    _egg_rarity_visuals.clear()
    _egg_traits_per_rarity.clear()
    var path: String = "res://data/configs/eggs.json"
    if not FileAccess.file_exists(path):
        push_warning("eggs.json not found at %s" % path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid eggs.json contents")
        return
    var feed_value: Variant = parsed.get("queen_feed", {})
    if typeof(feed_value) == TYPE_DICTIONARY:
        for key in feed_value.keys():
            var tier: String = String(key)
            var entry_value: Variant = feed_value.get(key, {})
            if typeof(entry_value) != TYPE_DICTIONARY:
                continue
            var cost: Dictionary = _parse_resource_amounts(entry_value.get("cost", {}))
            _egg_feed_costs[StringName(tier)] = cost
    var hatch_value: Variant = parsed.get("hatch_seconds", {})
    if typeof(hatch_value) == TYPE_DICTIONARY:
        for key in hatch_value.keys():
            var tier_hatch: String = String(key)
            var amount: Variant = hatch_value.get(key, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                _egg_hatch_seconds[StringName(tier_hatch)] = float(amount)
    var bump_value: Variant = parsed.get("rarity_bump", {})
    if typeof(bump_value) == TYPE_DICTIONARY:
        for key in bump_value.keys():
            var bump_key: String = String(key)
            var amount_bump: Variant = bump_value.get(key, 0.0)
            if typeof(amount_bump) == TYPE_FLOAT or typeof(amount_bump) == TYPE_INT:
                _egg_bump_probs[bump_key] = float(amount_bump)
    var visual_value: Variant = parsed.get("rarity_visuals", {})
    if typeof(visual_value) == TYPE_DICTIONARY:
        for key in visual_value.keys():
            var tier_visual: String = String(key)
            var entry_visual: Variant = visual_value.get(key, {})
            if typeof(entry_visual) != TYPE_DICTIONARY:
                continue
            var outline_value: Variant = entry_visual.get("outline", "")
            if typeof(outline_value) == TYPE_STRING:
                _egg_rarity_visuals[StringName(tier_visual)] = {
                    "outline": String(outline_value)
                }
    var traits_value: Variant = parsed.get("traits_per_rarity", {})
    if typeof(traits_value) == TYPE_DICTIONARY:
        for key in traits_value.keys():
            var tier_traits: String = String(key)
            var count_value: Variant = traits_value.get(key, 0)
            if typeof(count_value) == TYPE_FLOAT or typeof(count_value) == TYPE_INT:
                _egg_traits_per_rarity[StringName(tier_traits)] = int(round(float(count_value)))

func load_items() -> void:
    _item_ids.clear()
    var path: String = "res://data/configs/items.json"
    if not FileAccess.file_exists(path):
        push_warning("items.json not found at %s" % path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return
    var text_json: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text_json)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Invalid items.json contents")
        return
    var list_value: Variant = parsed.get("ids", [])
    if typeof(list_value) != TYPE_ARRAY:
        push_warning("Invalid items.json: expected 'ids' array")
        return
    for entry in list_value:
        if typeof(entry) == TYPE_STRING or typeof(entry) == TYPE_STRING_NAME:
            _item_ids.append(StringName(String(entry)))

func get_buildable_cell_types() -> Array[StringName]:
    return _buildable_ids.duplicate()

func get_cell_cost(cell_type: StringName) -> Dictionary:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var cost: Variant = def.get("cost", {})
    if typeof(cost) == TYPE_DICTIONARY:
        var parsed: Dictionary = {}
        for key in cost.keys():
            var amount: Variant = cost[key]
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                parsed[StringName(String(key))] = int(round(float(amount)))
        return parsed
    return {}

func get_cell_build_task(cell_type: StringName) -> Dictionary:
    return _parse_task_config(String(cell_type), "build")

func get_cell_repair_task(cell_type: StringName) -> Dictionary:
    return _parse_task_config(String(cell_type), "repair")

func get_cell_requires_bee(cell_type: StringName) -> bool:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("requires_bee", false)
    if typeof(value) == TYPE_BOOL:
        return bool(value)
    if typeof(value) == TYPE_INT:
        return int(value) != 0
    return false

func get_cell_build_seconds(cell_type: StringName) -> float:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("build_seconds", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return max(0.0, float(value))
    return 0.0

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

func _parse_task_config(cell_type: String, key: String) -> Dictionary:
    var def: Dictionary = _cell_defs.get(cell_type, {})
    if def.is_empty():
        return {}
    var task_value: Variant = def.get(key, {})
    if typeof(task_value) != TYPE_DICTIONARY:
        return {}
    var task: Dictionary = {}
    var cost_value: Variant = task_value.get("cost", {})
    if typeof(cost_value) == TYPE_DICTIONARY:
        var cost: Dictionary = {}
        for resource in cost_value.keys():
            var amount: Variant = cost_value.get(resource, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                cost[StringName(String(resource))] = int(round(float(amount)))
        if not cost.is_empty():
            task["cost"] = cost
        else:
            task["cost"] = {}
    else:
        task["cost"] = {}
    var requires_bee_value: Variant = task_value.get("requires_bee", false)
    if typeof(requires_bee_value) == TYPE_BOOL:
        task["requires_bee"] = requires_bee_value
    elif typeof(requires_bee_value) == TYPE_INT:
        task["requires_bee"] = int(requires_bee_value) != 0
    else:
        task["requires_bee"] = false
    var seconds_value: Variant = task_value.get("seconds", 0.0)
    if typeof(seconds_value) == TYPE_FLOAT or typeof(seconds_value) == TYPE_INT:
        task["seconds"] = max(0.0, float(seconds_value))
    else:
        task["seconds"] = 0.0
    var bonus_value: Variant = task_value.get("trait_construction_bonus", 0.0)
    if typeof(bonus_value) == TYPE_FLOAT or typeof(bonus_value) == TYPE_INT:
        task["trait_construction_bonus"] = max(0.0, float(bonus_value))
    else:
        task["trait_construction_bonus"] = 0.0
    return task

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

func get_cell_post_hatch_type(cell_type: StringName) -> StringName:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("post_hatch", "")
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        return StringName(String(value))
    return StringName("")

func get_cell_repair_config(cell_type: StringName) -> Dictionary:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var repair: Variant = def.get("repair", {})
    if typeof(repair) != TYPE_DICTIONARY:
        return {}
    var config: Dictionary = {}
    config["cost"] = _parse_resource_amounts(repair.get("cost", {}))
    var requires_bee_value: Variant = repair.get("requires_bee", false)
    if typeof(requires_bee_value) == TYPE_BOOL:
        config["requires_bee"] = bool(requires_bee_value)
    elif typeof(requires_bee_value) == TYPE_INT:
        config["requires_bee"] = int(requires_bee_value) != 0
    else:
        config["requires_bee"] = false
    var seconds_value: Variant = repair.get("seconds", 0.0)
    if typeof(seconds_value) == TYPE_FLOAT or typeof(seconds_value) == TYPE_INT:
        config["seconds"] = max(0.0, float(seconds_value))
    else:
        config["seconds"] = 0.0
    var bonus_value: Variant = repair.get("trait_construction_bonus", 0.0)
    if typeof(bonus_value) == TYPE_FLOAT or typeof(bonus_value) == TYPE_INT:
        config["trait_construction_bonus"] = max(0.0, float(bonus_value))
    return config

func get_cell_trait_construction_bonus(cell_type: StringName) -> float:
    var def: Dictionary = _cell_defs.get(String(cell_type), {})
    var value: Variant = def.get("trait_construction_bonus", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return max(0.0, float(value))
    return 0.0

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

func eggs_get_traits_per_rarity(tier: StringName) -> int:
    var key_string: String = String(tier)
    if key_string.is_empty():
        key_string = "Common"
    var key: StringName = StringName(key_string)
    if _egg_traits_per_rarity.has(key):
        return int(_egg_traits_per_rarity[key])
    return int(_egg_traits_per_rarity.get(key_string, 0))

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
            result[StringName(String(key))] = int(round(float(amount)))
    return result

func eggs_get_feed_cost(tier: StringName) -> Dictionary:
    return _egg_feed_costs.get(tier, {}).duplicate(true)

func eggs_get_hatch_secs(tier: StringName) -> float:
    return float(_egg_hatch_seconds.get(tier, 0.0))

func eggs_bump_prob(key: String) -> float:
    return float(_egg_bump_probs.get(key, 0.0))

func eggs_get_rarity_outline_color(tier: StringName) -> Color:
    var entry: Dictionary = _egg_rarity_visuals.get(tier, {})
    var outline: Variant = entry.get("outline", "")
    if typeof(outline) == TYPE_STRING and not String(outline).is_empty():
        return Color(String(outline))
    return Color.WHITE

func get_item_ids() -> Array[StringName]:
    return _item_ids.duplicate()
