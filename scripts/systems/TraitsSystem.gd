extends Node
class_name TraitsSystem

const TRAIT_CONSTRUCTION := StringName("Construction")
const TRAIT_GATHER := StringName("Gather")

const KEY_BUILD_BONUS := StringName("build_time_bonus_seconds")
const KEY_REPAIR_BONUS := StringName("repair_time_bonus_seconds")
const KEY_HARVEST_MULT := StringName("harvest_trickle_multiplier")

const DEFAULTS := {
    StringName("gather_multiplier"): 1.1,
    StringName("build_bonus_seconds"): 3.0,
    StringName("repair_bonus_seconds"): 3.0
}

var _cfg: Dictionary = {}
var _defaults: Dictionary = DEFAULTS.duplicate()
var _traits_by_id: Dictionary = {}
var _rarity_pools: Dictionary = {}

func _ready() -> void:
    _reload_cfg()

func generate_for_rarity(rarity: StringName, count: int, rng: RandomNumberGenerator = null) -> Array[StringName]:
    _ensure_loaded()
    if count <= 0:
        return []
    if rng == null:
        rng = RandomNumberGenerator.new()
        rng.randomize()
    var pool: Array = _get_rarity_pool(rarity)
    if pool.is_empty():
        return []
    var bag: Array = pool.duplicate(true)
    var out: Array[StringName] = []
    count = clamp(count, 0, bag.size())
    for i in range(count):
        if bag.is_empty():
            break
        var total_weight := 0.0
        for entry in bag:
            total_weight += _entry_weight(entry)
        var chosen_index := 0
        if total_weight <= 0.0:
            chosen_index = rng.randi_range(0, bag.size() - 1)
        else:
            var pick := rng.randf() * total_weight
            var acc := 0.0
            for j in range(bag.size()):
                acc += _entry_weight(bag[j])
                if pick <= acc:
                    chosen_index = j
                    break
        var chosen: Dictionary = bag[chosen_index]
        bag.remove_at(chosen_index)
        var trait_id := _to_string_name(chosen.get("id", StringName("")))
        if trait_id != StringName(""):
            out.append(trait_id)
    return out

func bee_has(bee_id: int, trait_id: StringName) -> bool:
    if bee_id <= 0 or trait_id == StringName(""):
        return false
    if typeof(GameState) != TYPE_OBJECT:
        return false
    var bee: Variant = GameState.bees.get(bee_id, null)
    if typeof(bee) != TYPE_DICTIONARY:
        return false
    var traits_value: Variant = bee.get("traits", [])
    if typeof(traits_value) != TYPE_ARRAY:
        return false
    var target: StringName = _to_string_name(trait_id)
    if target == StringName(""):
        return false
    for entry in traits_value:
        if _to_string_name(entry) == target:
            return true
    return false

func build_time_bonus_seconds(bee_id: int) -> float:
    if not bee_has(bee_id, TRAIT_CONSTRUCTION):
        return 0.0
    return _trait_effect_float(TRAIT_CONSTRUCTION, KEY_BUILD_BONUS, _default_float(StringName("build_bonus_seconds")))

func repair_time_bonus_seconds(bee_id: int) -> float:
    if not bee_has(bee_id, TRAIT_CONSTRUCTION):
        return 0.0
    return _trait_effect_float(TRAIT_CONSTRUCTION, KEY_REPAIR_BONUS, _default_float(StringName("repair_bonus_seconds")))

func harvest_multiplier(bee_id: int) -> float:
    if not bee_has(bee_id, TRAIT_GATHER):
        return 1.0
    var mult := _trait_effect_float(TRAIT_GATHER, KEY_HARVEST_MULT, _default_float(StringName("gather_multiplier")))
    return max(mult, 0.0)

func get_trait_data(trait_id: StringName) -> Dictionary:
    _ensure_loaded()
    trait_id = _to_string_name(trait_id)
    if _traits_by_id.has(trait_id):
        return _traits_by_id.get(trait_id, {}).duplicate(true)
    return {}

func _ensure_loaded() -> void:
    if _rarity_pools.is_empty() and _traits_by_id.is_empty():
        _reload_cfg()

func _reload_cfg() -> void:
    _cfg.clear()
    _traits_by_id.clear()
    _rarity_pools.clear()
    _defaults = DEFAULTS.duplicate()
    if typeof(ConfigDB) != TYPE_OBJECT:
        return
    _cfg = ConfigDB.get_traits_cfg()
    var trait_list: Variant = _cfg.get("traits", [])
    if typeof(trait_list) == TYPE_ARRAY:
        for entry in trait_list:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var trait_id := _to_string_name(entry.get("id", StringName("")))
            if trait_id == StringName(""):
                continue
            _traits_by_id[trait_id] = entry.duplicate(true)
    var defaults_value: Variant = _cfg.get("defaults", {})
    if typeof(defaults_value) == TYPE_DICTIONARY:
        for key in defaults_value.keys():
            var default_key := _to_string_name(key)
            if default_key == StringName(""):
                continue
            var value: Variant = defaults_value.get(key)
            if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
                _defaults[default_key] = float(value)
    var pools_value: Variant = _cfg.get("rarity_pools", {})
    if typeof(pools_value) == TYPE_DICTIONARY:
        for key in pools_value.keys():
            var rarity := _to_string_name(key)
            if rarity == StringName(""):
                continue
            var arr: Array = []
            var pool_value: Variant = pools_value.get(key, [])
            if typeof(pool_value) == TYPE_ARRAY:
                for pool_entry in pool_value:
                    if typeof(pool_entry) != TYPE_DICTIONARY:
                        continue
                    var trait_id := _to_string_name(pool_entry.get("id", StringName("")))
                    if trait_id == StringName(""):
                        continue
                    var weight_value: Variant = pool_entry.get("weight", 0.0)
                    var weight := 0.0
                    if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
                        weight = max(float(weight_value), 0.0)
                    else:
                        weight = 0.0
                    arr.append({"id": trait_id, "weight": weight})
            if not arr.is_empty():
                _rarity_pools[rarity] = arr
    if _rarity_pools.is_empty() and not _traits_by_id.is_empty():
        var fallback: Array = []
        for trait_id in _traits_by_id.keys():
            fallback.append({"id": trait_id, "weight": 1.0})
        _rarity_pools[StringName("Common")] = fallback.duplicate(true)
        _rarity_pools[StringName("Unique")] = fallback.duplicate(true)
        _rarity_pools[StringName("Rare")] = fallback.duplicate(true)

func _get_rarity_pool(rarity: StringName) -> Array:
    if rarity != StringName("") and _rarity_pools.has(rarity):
        return _rarity_pools.get(rarity, []).duplicate(true)
    var key_string := String(rarity)
    if _rarity_pools.has(StringName(key_string)):
        return _rarity_pools.get(StringName(key_string), []).duplicate(true)
    if _traits_by_id.is_empty():
        return []
    var fallback: Array = []
    for trait_id in _traits_by_id.keys():
        fallback.append({"id": trait_id, "weight": 1.0})
    return fallback

func _trait_effect_float(trait_id: StringName, key: StringName, fallback: float) -> float:
    var trait_data: Dictionary = _traits_by_id.get(trait_id, {})
    if trait_data.is_empty():
        return fallback
    var effects_value: Variant = trait_data.get("effects", {})
    if typeof(effects_value) != TYPE_DICTIONARY:
        return fallback
    var value: Variant = effects_value.get(key, null)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return fallback

func _default_float(key: StringName) -> float:
    var value: Variant = _defaults.get(key, DEFAULTS.get(key, 0.0))
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return float(DEFAULTS.get(key, 0.0))

func _entry_weight(entry: Variant) -> float:
    if typeof(entry) != TYPE_DICTIONARY:
        return 0.0
    var value: Variant = entry.get("weight", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return max(float(value), 0.0)
    return 0.0

func _to_string_name(value: Variant) -> StringName:
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        var s := String(value)
        if s.is_empty():
            return StringName("")
        return StringName(s)
    return StringName("")
