extends Node
class_name TraitsSystem

const KEY_HARVEST_TRICKLE_MULTIPLIER := StringName("harvest_trickle_multiplier")
const DEFAULT_KEY_GATHER_MULTIPLIER := StringName("gather_multiplier")
const TRAIT_GATHER := StringName("Gather")

const FALLBACK_TRAITS := [
    {
        "id": "Construction",
        "name": "Construction",
        "desc": "Shortens build and repair tasks.",
        "effects": {
            "build_time_bonus_seconds": 3.0,
            "repair_time_bonus_seconds": 3.0
        }
    },
    {
        "id": "Gather",
        "name": "Gather",
        "desc": "Improves gathering output.",
        "effects": {
            "harvest_trickle_multiplier": 1.1
        }
    },
    {
        "id": "Brewer",
        "name": "Brewer",
        "desc": "Specialises in honey vats.",
        "effects": {}
    }
]

const FALLBACK_DEFAULTS := {
    "gather_multiplier": 1.1,
    "build_bonus_seconds": 3.0,
    "repair_bonus_seconds": 3.0
}

var _rng := RandomNumberGenerator.new()
var _traits_by_id: Dictionary = {}
var _rarity_pools: Dictionary = {}
var _defaults: Dictionary = {}

func _ready() -> void:
    _rng.randomize()
    _reload_data()

func generate(count: int, rarity: StringName = StringName("")) -> Array:
    if count <= 0:
        return []
    _ensure_data_loaded()
    var pool: Array = _create_selection_pool(rarity)
    if pool.is_empty():
        return []
    var remaining: int = min(count, pool.size())
    var selected: Array = []
    while remaining > 0 and not pool.is_empty():
        var index: int = _pick_from_pool(pool)
        if index < 0:
            break
        var info: Dictionary = pool.pop_at(index)
        var trait_id: StringName = _as_string_name(info.get("id", StringName("")))
        if trait_id == StringName(""):
            continue
        var trait_data: Dictionary = _traits_by_id.get(trait_id, {})
        if trait_data.is_empty():
            continue
        selected.append(trait_data.duplicate(true))
        remaining -= 1
    return selected

func bee_has_trait(bee: Dictionary, trait_id: StringName) -> bool:
    if trait_id == StringName(""):
        return false
    var traits_value: Variant = bee.get("traits", [])
    if typeof(traits_value) != TYPE_ARRAY:
        return false
    for entry in traits_value:
        if _trait_id_from_entry(entry) == trait_id:
            return true
    return false

func harvest_multiplier(bee_id: int) -> float:
    _ensure_data_loaded()
    if bee_id <= 0:
        return 1.0
    if typeof(GameState) != TYPE_OBJECT:
        return 1.0
    var bee: Dictionary = GameState.get_bee_by_id(bee_id)
    if bee.is_empty():
        return 1.0
    var traits_value: Variant = bee.get("traits", [])
    if typeof(traits_value) != TYPE_ARRAY:
        return 1.0
    var multiplier: float = 1.0
    for entry in traits_value:
        var effects: Dictionary = _effects_for_entry(entry)
        if effects.is_empty():
            if _trait_id_from_entry(entry) == TRAIT_GATHER:
                multiplier *= _default_gather_multiplier()
            continue
        var value: Variant = effects.get(KEY_HARVEST_TRICKLE_MULTIPLIER, null)
        if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
            multiplier *= max(0.0, float(value))
        elif _trait_id_from_entry(entry) == TRAIT_GATHER:
            multiplier *= _default_gather_multiplier()
    return max(multiplier, 0.0)

func _ensure_data_loaded() -> void:
    if _traits_by_id.is_empty():
        _reload_data()

func _reload_data() -> void:
    _traits_by_id.clear()
    _rarity_pools.clear()
    _defaults.clear()
    if typeof(ConfigDB) != TYPE_OBJECT:
        _use_fallback_traits()
        return
    var cfg: Dictionary = ConfigDB.get_traits_cfg()
    var trait_list: Variant = cfg.get("traits", [])
    if typeof(trait_list) == TYPE_ARRAY:
        for entry in trait_list:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var id: StringName = _as_string_name(entry.get("id", StringName("")))
            if id == StringName(""):
                continue
            _traits_by_id[id] = entry.duplicate(true)
    if _traits_by_id.is_empty():
        _use_fallback_traits()
    var pools_value: Variant = cfg.get("rarity_pools", {})
    if typeof(pools_value) == TYPE_DICTIONARY:
        for key in pools_value.keys():
            var rarity: StringName = _as_string_name(key)
            if rarity == StringName(""):
                continue
            var entries: Array = []
            var list_value: Variant = pools_value.get(key, [])
            if typeof(list_value) == TYPE_ARRAY:
                for pool_entry in list_value:
                    if typeof(pool_entry) != TYPE_DICTIONARY:
                        continue
                    var trait_id: StringName = _as_string_name(pool_entry.get("id", StringName("")))
                    if trait_id == StringName(""):
                        continue
                    var weight: float = 0.0
                    var weight_value: Variant = pool_entry.get("weight", 0.0)
                    if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
                        weight = max(float(weight_value), 0.0)
                    entries.append({"id": trait_id, "weight": weight})
            if not entries.is_empty():
                _rarity_pools[rarity] = entries
    var defaults_value: Variant = cfg.get("defaults", {})
    if typeof(defaults_value) == TYPE_DICTIONARY:
        for key in defaults_value.keys():
            var default_key: StringName = _as_string_name(key)
            if default_key == StringName(""):
                continue
            _defaults[default_key] = defaults_value[key]
    if _defaults.is_empty():
        _apply_fallback_defaults()
    else:
        _apply_missing_defaults()

func _use_fallback_traits() -> void:
    for entry in FALLBACK_TRAITS:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id_string: String = String(entry.get("id", ""))
        if id_string.is_empty():
            continue
        var trait_id: StringName = StringName(id_string)
        var trait_data: Dictionary = {
            "id": trait_id,
            "name": String(entry.get("name", id_string)),
            "desc": String(entry.get("desc", "")),
            "effects": {}
        }
        var effects_value: Variant = entry.get("effects", {})
        if typeof(effects_value) == TYPE_DICTIONARY:
            var effects: Dictionary = {}
            for key in effects_value.keys():
                effects[StringName(String(key))] = effects_value[key]
            trait_data["effects"] = effects
        _traits_by_id[trait_id] = trait_data
    _rarity_pools.clear()
    _apply_fallback_defaults()

func _apply_fallback_defaults() -> void:
    for key in FALLBACK_DEFAULTS.keys():
        _defaults[StringName(key)] = FALLBACK_DEFAULTS[key]

func _apply_missing_defaults() -> void:
    for key in FALLBACK_DEFAULTS.keys():
        var default_key: StringName = StringName(key)
        if not _defaults.has(default_key):
            _defaults[default_key] = FALLBACK_DEFAULTS[key]

func _create_selection_pool(rarity: StringName) -> Array:
    var pool: Array = []
    if rarity != StringName("") and _rarity_pools.has(rarity):
        var entries: Variant = _rarity_pools.get(rarity, [])
        if typeof(entries) == TYPE_ARRAY:
            for entry in entries:
                if typeof(entry) != TYPE_DICTIONARY:
                    continue
                pool.append(entry.duplicate(true))
        return pool
    for key in _traits_by_id.keys():
        var trait_id: StringName = _as_string_name(key)
        if trait_id == StringName(""):
            continue
        pool.append({"id": trait_id, "weight": 1.0})
    return pool

func _pick_from_pool(pool: Array) -> int:
    if pool.is_empty():
        return -1
    var total_weight: float = 0.0
    for entry in pool:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        total_weight += max(0.0, float(entry.get("weight", 0.0)))
    if total_weight <= 0.0:
        return _rng.randi_range(0, pool.size() - 1)
    var threshold: float = _rng.randf() * total_weight
    var accum: float = 0.0
    for i in pool.size():
        var item: Variant = pool[i]
        if typeof(item) != TYPE_DICTIONARY:
            continue
        var weight: float = max(0.0, float(item.get("weight", 0.0)))
        accum += weight
        if threshold <= accum:
            return i
    return pool.size() - 1

func _trait_id_from_entry(entry: Variant) -> StringName:
    if typeof(entry) == TYPE_DICTIONARY:
        return _as_string_name(entry.get("id", StringName("")))
    return _as_string_name(entry)

func _effects_for_entry(entry: Variant) -> Dictionary:
    if typeof(entry) == TYPE_DICTIONARY:
        var effects_value: Variant = entry.get("effects", {})
        if typeof(effects_value) == TYPE_DICTIONARY:
            return effects_value
        var trait_id: StringName = _trait_id_from_entry(entry)
        if trait_id != StringName("") and _traits_by_id.has(trait_id):
            var trait_info: Dictionary = _traits_by_id.get(trait_id, {})
            var trait_effects: Variant = trait_info.get("effects", {})
            if typeof(trait_effects) == TYPE_DICTIONARY:
                return trait_effects
    else:
        var id: StringName = _trait_id_from_entry(entry)
        if id != StringName("") and _traits_by_id.has(id):
            var stored: Dictionary = _traits_by_id.get(id, {})
            var stored_effects: Variant = stored.get("effects", {})
            if typeof(stored_effects) == TYPE_DICTIONARY:
                return stored_effects
    return {}

func _default_gather_multiplier() -> float:
    var value: Variant = _defaults.get(DEFAULT_KEY_GATHER_MULTIPLIER, 1.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return max(0.0, float(value))
    return 1.0

func _as_string_name(value: Variant) -> StringName:
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        var s: String = String(value)
        if s.is_empty():
            return StringName("")
        return StringName(s)
    return StringName("")
