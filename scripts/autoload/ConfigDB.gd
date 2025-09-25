# -----------------------------------------------------------------------------
# File: scripts/autoload/ConfigDB.gd
# Purpose: Loads JSON configuration and exposes typed lookup helpers
# Depends: FileAccess, JSON, GameState consumers
# Notes: Validates config structure and reports parsing issues eagerly
# -----------------------------------------------------------------------------

## ConfigDB
## Central repository of configuration data loaded from data/configs.
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

const RESOURCE_NAME_OVERRIDES := {
    "Honey": {"display": "Honey", "short": "Honey"},
    "Comb": {"display": "Comb", "short": "Comb"},
    "Pollen": {"display": "Pollen", "short": "Pollen"},
    "NectarCommon": {"display": "Common Nectar", "short": "Nectar"},
    "NectarSweet": {"display": "Sweet Nectar", "short": "Nectar"},
    "NectarRich": {"display": "Rich Nectar", "short": "Nectar"},
    "PetalWhite": {"display": "White Petals", "short": "White"},
    "PetalPink": {"display": "Pink Petals", "short": "Pink"},
    "PetalYellow": {"display": "Yellow Petals", "short": "Yellow"},
    "PetalRed": {"display": "Red Petals", "short": "Red"},
    "PetalBlue": {"display": "Blue Petals", "short": "Blue"},
    "PetalPurple": {"display": "Purple Petals", "short": "Purple"}
}

var _cell_defs: Dictionary = {}
var _buildable_ids: Array[StringName] = []
var _resource_defs: Array[Dictionary] = []
var _resource_lookup: Dictionary = {}
var _offer_pools: Dictionary = {
    "harvests": [],
    "item_quests": []
}
var _offer_lookup: Dictionary = {
    "harvests": {},
    "item_quests": {}
}
var _offer_weights: Dictionary = {
    "harvests": {},
    "item_quests": {}
}
var _offer_slots: Dictionary = {
    "harvests": 0,
    "item_quests": 0
}
var _offer_tick_seconds: float = 1.0
var _offer_delay_ratio: float = 0.05
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
var _item_defs: Dictionary = {}
var _item_order: Array[StringName] = []
var _start_values: Dictionary = {}
var _start_resources: Dictionary = {}
var _start_inventory: Dictionary = {}
var _start_cells: int = 0
var _start_workers: int = 0
var _abilities_cfg: Dictionary = {}
var _abilities_pool: Array[Dictionary] = []
var _abilities_lookup: Dictionary = {}

## Opens and parses a JSON file, reporting errors and returning the raw Variant.
func _load_json(path: String, context: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("%s not found at %s" % [context, path])
        return null
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Failed to open %s" % path)
        return null
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) == TYPE_NIL:
        push_error("Invalid JSON in %s" % context)
        return null
    return parsed

## Convenience wrapper that ensures the parsed JSON is a dictionary.
func _load_json_dict(path: String, context: String) -> Dictionary:
    var parsed: Variant = _load_json(path, context)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("%s must be a JSON object" % context)
        return {}
    return parsed

## Convenience wrapper that ensures the parsed JSON is an array.
func _load_json_array(path: String, context: String) -> Array:
    var parsed: Variant = _load_json(path, context)
    if typeof(parsed) != TYPE_ARRAY:
        push_error("%s must be a JSON array" % context)
        return []
    return parsed

func _ready() -> void:
    load_cells()
    load_resources()
    load_start_values()
    load_offers()
    load_queens()
    load_threats()
    load_boss()
    load_traits()
    load_eggs()
    load_items()
    load_abilities()

func load_cells() -> void:
    _cell_defs.clear()
    _buildable_ids.clear()
    var path: String = "res://data/configs/cells.json"
    var parsed: Dictionary = _load_json_dict(path, "cells.json")
    if parsed.is_empty():
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
    var parsed: Dictionary = _load_json_dict(path, "resources.json")
    if parsed.is_empty():
        return
    var base_cap_value: Variant = parsed.get("base_caps_per_resource", 0)
    var base_cap: int = 0
    if typeof(base_cap_value) == TYPE_FLOAT or typeof(base_cap_value) == TYPE_INT:
        base_cap = max(int(round(float(base_cap_value))), 0)
    var ids_value: Variant = parsed.get("ids", [])
    if typeof(ids_value) != TYPE_ARRAY:
        push_error("Invalid resources.json: expected 'ids' array")
        return
    for entry in ids_value:
        var id_string: String = String(entry)
        if id_string.is_empty():
            continue
        var id: StringName = StringName(id_string)
        var name_info: Dictionary = RESOURCE_NAME_OVERRIDES.get(id_string, {})
        var display_name: String = String(name_info.get("display", _prettify_resource_name(id_string)))
        var short_name: String = String(name_info.get("short", display_name))
        var def := {
            "id": id,
            "display_name": display_name,
            "short_name": short_name,
            "cap": base_cap,
            "initial": 0
        }
        _resource_defs.append(def)
        _resource_lookup[id_string] = def

func load_start_values() -> void:
    _start_values.clear()
    _start_resources.clear()
    _start_inventory.clear()
    _start_cells = 0
    _start_workers = 0
    var path: String = "res://data/configs/start_values.json"
    var parsed: Dictionary = _load_json_dict(path, "start_values.json")
    if parsed.is_empty():
        return
    _start_values = parsed
    var cells_value: Variant = parsed.get("start_cells", 0)
    if typeof(cells_value) == TYPE_FLOAT or typeof(cells_value) == TYPE_INT:
        _start_cells = max(int(round(float(cells_value))), 0)
    var workers_value: Variant = parsed.get("start_workers", 0)
    if typeof(workers_value) == TYPE_FLOAT or typeof(workers_value) == TYPE_INT:
        _start_workers = max(int(round(float(workers_value))), 0)
    var resources_value: Variant = parsed.get("resources", {})
    if typeof(resources_value) == TYPE_DICTIONARY:
        for key in resources_value.keys():
            var amount: Variant = resources_value.get(key, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                var id: StringName = StringName(String(key))
                _start_resources[id] = int(round(float(amount)))
    var inventory_value: Variant = parsed.get("inventory", {})
    if typeof(inventory_value) == TYPE_DICTIONARY:
        for key in inventory_value.keys():
            var amount: Variant = inventory_value.get(key, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                _start_inventory[String(key)] = int(round(float(amount)))

func load_offers() -> void:
    for key in _offer_pools.keys():
        _offer_pools[key] = []
    for key in _offer_lookup.keys():
        _offer_lookup[key] = {}
    for key in _offer_weights.keys():
        _offer_weights[key] = {}
    _offer_slots["harvests"] = 0
    _offer_slots["item_quests"] = 0
    _offer_tick_seconds = 1.0
    _offer_delay_ratio = 0.05
    var path: String = "res://data/configs/offers.json"
    var parsed: Dictionary = _load_json_dict(path, "offers.json")
    if parsed.is_empty():
        return
    _offer_pools["harvests"] = _parse_offer_pool(parsed.get("harvests_pool", []), "harvests")
    _offer_pools["item_quests"] = _parse_offer_pool(parsed.get("item_quests_pool", []), "item_quests")
    var weights_value: Variant = parsed.get("weights", {})
    if typeof(weights_value) == TYPE_DICTIONARY:
        _offer_weights["harvests"] = _parse_offer_weights(weights_value.get("harvests", {}))
        _offer_weights["item_quests"] = _parse_offer_weights(weights_value.get("item_quests", {}))
    var slots_value: Variant = parsed.get("slots", {})
    if typeof(slots_value) == TYPE_DICTIONARY:
        var harvest_slots: Variant = slots_value.get("harvests", 0)
        var contract_slots: Variant = slots_value.get("item_quests", 0)
        if typeof(harvest_slots) == TYPE_FLOAT or typeof(harvest_slots) == TYPE_INT:
            _offer_slots["harvests"] = max(int(round(float(harvest_slots))), 0)
        if typeof(contract_slots) == TYPE_FLOAT or typeof(contract_slots) == TYPE_INT:
            _offer_slots["item_quests"] = max(int(round(float(contract_slots))), 0)
    var tick_value: Variant = parsed.get("tick_seconds", 1.0)
    if typeof(tick_value) == TYPE_FLOAT or typeof(tick_value) == TYPE_INT:
        _offer_tick_seconds = max(float(tick_value), 0.1)
    var delay_value: Variant = parsed.get("delay_ratio", 0.05)
    if typeof(delay_value) == TYPE_FLOAT or typeof(delay_value) == TYPE_INT:
        _offer_delay_ratio = clamp(float(delay_value), 0.0, 1.0)

func _parse_offer_pool(source: Variant, kind: String) -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    if typeof(source) != TYPE_ARRAY:
        return list
    for entry in source:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = entry.get("id", "")
        if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
            continue
        var id_string: String = String(id_value)
        if id_string.is_empty():
            continue
        var offer: Dictionary = {}
        var id: StringName = StringName(id_string)
        offer["id"] = id
        offer["kind"] = StringName(kind)
        offer["name"] = String(entry.get("name", id_string))
        offer["required_bees"] = int(entry.get("required_bees", 0))
        offer["duration_seconds"] = float(entry.get("duration_seconds", 0))
        offer["cost"] = _parse_resource_amounts(entry.get("cost", {}))
        if kind == "harvests":
            offer["outputs"] = _parse_resource_amounts(entry.get("outputs", {}))
        else:
            offer["outputs"] = {}
        if kind == "item_quests":
            offer["reward"] = _parse_resource_amounts(entry.get("reward", {}))
        else:
            offer["reward"] = {}
        list.append(offer)
        var lookup: Dictionary = _offer_lookup.get(kind, {})
        lookup[id_string] = offer
        _offer_lookup[kind] = lookup
    return list

func _parse_offer_weights(source: Variant) -> Dictionary:
    var weights: Dictionary = {}
    if typeof(source) != TYPE_DICTIONARY:
        return weights
    for key in source.keys():
        var weight_value: Variant = source.get(key, 0)
        if typeof(weight_value) != TYPE_FLOAT and typeof(weight_value) != TYPE_INT:
            continue
        var id_string: String = String(key)
        weights[id_string] = max(float(weight_value), 0.0)
    return weights

func load_queens() -> void:
    _queen_defs.clear()
    var path: String = "res://data/configs/queens.json"
    var parsed: Dictionary = _load_json_dict(path, "queens.json")
    if parsed.is_empty():
        return
    var list_value: Variant = parsed.get("queens", [])
    if typeof(list_value) != TYPE_ARRAY:
        push_error("Invalid queens.json: expected 'queens' array")
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
    var parsed: Dictionary = _load_json_dict(path, "threats.json")
    if parsed.is_empty():
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
    var parsed: Dictionary = _load_json_dict(path, "boss.json")
    if parsed.is_empty():
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
    var parsed: Dictionary = _load_json_dict(path, "traits.json")
    if parsed.is_empty():
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
    var parsed: Dictionary = _load_json_dict(path, "eggs.json")
    if parsed.is_empty():
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
    _item_defs.clear()
    _item_order.clear()
    var path: String = "res://data/configs/items.json"
    var parsed: Dictionary = _load_json_dict(path, "items.json")
    if parsed.is_empty():
        return
    var items_value: Variant = parsed.get("items", [])
    if typeof(items_value) == TYPE_ARRAY:
        for entry in items_value:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var id_value: Variant = entry.get("id", "")
            if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
                continue
            var id_string: String = String(id_value)
            if id_string.is_empty():
                continue
            var def: Dictionary = {}
            def["id"] = StringName(id_string)
            def["name"] = String(entry.get("name", id_string))
            def["icon"] = String(entry.get("icon", ""))
            _item_defs[id_string] = def
    else:
        push_error("Invalid items.json: expected 'items' array")
    var order_value: Variant = parsed.get("order", [])
    if typeof(order_value) == TYPE_ARRAY:
        for entry in order_value:
            var id_string := String(entry)
            if id_string.is_empty():
                continue
            if _item_defs.has(id_string):
                var id: StringName = StringName(id_string)
                if not _item_order.has(id):
                    _item_order.append(id)
    for key in _item_defs.keys():
        var id: StringName = _item_defs[key].get("id", StringName(String(key)))
        if not _item_order.has(id):
            _item_order.append(id)
    _item_ids = _item_order.duplicate()

func load_abilities() -> void:
    _abilities_cfg.clear()
    _abilities_pool.clear()
    _abilities_lookup.clear()
    var path := "res://data/configs/abilities.json"
    var parsed: Dictionary = _load_json_dict(path, "abilities.json")
    if parsed.is_empty():
        return
    var cfg: Dictionary = {}
    var max_value: Variant = parsed.get("max_list", 0)
    if typeof(max_value) == TYPE_FLOAT or typeof(max_value) == TYPE_INT:
        cfg["max_list"] = max(int(round(float(max_value))), 0)
    else:
        cfg["max_list"] = 0
    var ritual_value: Variant = parsed.get("ritual", {})
    var ritual: Dictionary = {"seconds": 0.0, "comb_cost": 0}
    if typeof(ritual_value) == TYPE_DICTIONARY:
        var seconds_value: Variant = ritual_value.get("seconds", 0.0)
        if typeof(seconds_value) == TYPE_FLOAT or typeof(seconds_value) == TYPE_INT:
            ritual["seconds"] = max(float(seconds_value), 0.0)
        var comb_value: Variant = ritual_value.get("comb_cost", 0)
        if typeof(comb_value) == TYPE_FLOAT or typeof(comb_value) == TYPE_INT:
            ritual["comb_cost"] = max(int(round(float(comb_value))), 0)
    cfg["ritual"] = ritual
    var pool_value: Variant = parsed.get("pool", [])
    if typeof(pool_value) == TYPE_ARRAY:
        for entry in pool_value:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var ability: Dictionary = _parse_ability_entry(entry)
            if ability.is_empty():
                continue
            var id_string: String = String(ability.get("id", ""))
            if id_string.is_empty():
                continue
            _abilities_pool.append(ability)
            _abilities_lookup[id_string] = ability
    _abilities_cfg = cfg

func _parse_ability_entry(source: Dictionary) -> Dictionary:
    var ability: Dictionary = {}
    var id_value: Variant = source.get("id", "")
    var id_string: String = String(id_value)
    if id_string.is_empty():
        return {}
    ability["id"] = id_string
    ability["name"] = String(source.get("name", id_string.capitalize()))
    ability["desc"] = String(source.get("desc", ""))
    var weight_value: Variant = source.get("weight", 1.0)
    var weight: float = 1.0
    if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
        weight = max(float(weight_value), 0.0)
    ability["weight"] = weight
    ability["cost"] = _parse_ability_cost(source.get("cost", {}))
    var effect_value: Variant = source.get("effect", {})
    if typeof(effect_value) == TYPE_DICTIONARY:
        ability["effect"] = effect_value.duplicate(true)
    else:
        ability["effect"] = {}
    return ability

func _parse_ability_cost(value: Variant) -> Dictionary:
    var cost: Dictionary = {"resources": {}, "items": {}}
    if typeof(value) != TYPE_DICTIONARY:
        return cost
    var resources_value: Variant = value.get("resources", {})
    if typeof(resources_value) == TYPE_DICTIONARY:
        for key in resources_value.keys():
            var amount_value: Variant = resources_value.get(key, 0)
            var amount: int = 0
            if typeof(amount_value) == TYPE_FLOAT or typeof(amount_value) == TYPE_INT:
                amount = max(int(round(float(amount_value))), 0)
            if amount <= 0:
                continue
            var res_id: String = String(key)
            if res_id.is_empty():
                continue
            cost["resources"][res_id] = amount
    var items_value: Variant = value.get("items", {})
    if typeof(items_value) == TYPE_DICTIONARY:
        for key in items_value.keys():
            var qty_value: Variant = items_value.get(key, 0)
            var qty: int = 0
            if typeof(qty_value) == TYPE_FLOAT or typeof(qty_value) == TYPE_INT:
                qty = max(int(round(float(qty_value))), 0)
            if qty <= 0:
                continue
            var item_id: String = String(key)
            if item_id.is_empty():
                continue
            cost["items"][item_id] = qty
    return cost

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
    if _start_resources.has(resource_id):
        return int(_start_resources[resource_id])
    return int(_start_resources.get(String(resource_id), 0))

func get_resource_display_name(resource_id: StringName) -> String:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    return String(def.get("display_name", String(resource_id)))

func get_resource_short_name(resource_id: StringName) -> String:
    var def: Dictionary = _resource_lookup.get(String(resource_id), {})
    if def.has("short_name"):
        return String(def.get("short_name", ""))
    return get_resource_display_name(resource_id)

func offers_pool(kind: StringName) -> Array[Dictionary]:
    var key := String(kind)
    var source: Variant = _offer_pools.get(key, [])
    var list: Array[Dictionary] = []
    if typeof(source) != TYPE_ARRAY:
        return list
    for entry in source:
        if typeof(entry) == TYPE_DICTIONARY:
            list.append(entry.duplicate(true))
    return list

func offers_get(kind: StringName, id: StringName) -> Dictionary:
    var lookup: Dictionary = _offer_lookup.get(String(kind), {})
    var entry: Dictionary = lookup.get(String(id), {})
    return entry.duplicate(true)

func offers_weights(kind: StringName) -> Dictionary:
    var weights: Dictionary = _offer_weights.get(String(kind), {})
    return weights.duplicate(true)

func offers_slots(kind: StringName) -> int:
    return int(_offer_slots.get(String(kind), 0))

func offers_tick_seconds() -> float:
    return _offer_tick_seconds

func offers_delay_ratio() -> float:
    return _offer_delay_ratio

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

func _prettify_resource_name(id: String) -> String:
    if id.is_empty():
        return id
    var result := ""
    var prev_was_lower := false
    for i in id.length():
        var code: int = id.unicode_at(i)
        var ch: String = char(code)
        var is_letter: bool = ch.to_lower() != ch.to_upper()
        var is_upper: bool = is_letter and ch == ch.to_upper()
        if i > 0 and is_upper and prev_was_lower:
            result += " "
        result += ch
        prev_was_lower = is_letter and not is_upper
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
    return _item_order.duplicate()

func get_items_list() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for id in _item_order:
        var key: String = String(id)
        var def: Dictionary = _item_defs.get(key, {})
        if def.is_empty():
            continue
        var entry: Dictionary = {}
        entry["id"] = def.get("id", id)
        entry["name"] = String(def.get("name", String(id)))
        entry["icon"] = String(def.get("icon", ""))
        list.append(entry)
    return list

func get_item_def(id: StringName) -> Dictionary:
    var key: String = String(id)
    var def: Dictionary = _item_defs.get(key, {})
    return def.duplicate(true)

func get_start_resources() -> Dictionary:
    return _start_resources.duplicate(true)

func get_start_inventory() -> Dictionary:
    return _start_inventory.duplicate(true)

func get_start_cells() -> int:
    return _start_cells

func get_start_workers() -> int:
    return _start_workers

func abilities_max_list() -> int:
    return int(_abilities_cfg.get("max_list", 0))

func abilities_ritual_cfg() -> Dictionary:
    var ritual: Dictionary = _abilities_cfg.get("ritual", {})
    if typeof(ritual) == TYPE_DICTIONARY:
        return ritual.duplicate(true)
    return {"seconds": 0.0, "comb_cost": 0}

func abilities_pool() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for entry in _abilities_pool:
        list.append(entry.duplicate(true))
    return list

func abilities_get(id: StringName) -> Dictionary:
    var key: String = String(id)
    if key.is_empty():
        return {}
    var entry: Dictionary = _abilities_lookup.get(key, {})
    return entry.duplicate(true)

func abilities_pick_random(exclude_ids: Array = []) -> Dictionary:
    if _abilities_pool.is_empty():
        return {}
    var exclude: Dictionary = {}
    for value in exclude_ids:
        var id_string: String = String(value)
        if id_string.is_empty():
            continue
        exclude[id_string] = true
    var candidates: Array[Dictionary] = []
    var total_weight: float = 0.0
    for entry in _abilities_pool:
        var id_string: String = String(entry.get("id", ""))
        if id_string.is_empty():
            continue
        if exclude.has(id_string):
            continue
        var weight_value: Variant = entry.get("weight", 0.0)
        var weight: float = 0.0
        if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
            weight = max(float(weight_value), 0.0)
        if weight <= 0.0:
            continue
        candidates.append({"entry": entry, "weight": weight})
        total_weight += weight
    if candidates.is_empty() or total_weight <= 0.0:
        return {}
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var roll: float = rng.randf_range(0.0, total_weight)
    var accum: float = 0.0
    for candidate in candidates:
        accum += float(candidate.get("weight", 0.0))
        if roll <= accum:
            var picked: Variant = candidate.get("entry", {})
            if typeof(picked) == TYPE_DICTIONARY:
                return picked.duplicate(true)
            break
    var fallback: Variant = candidates.back().get("entry", {})
    if typeof(fallback) == TYPE_DICTIONARY:
        return fallback.duplicate(true)
    return {}
