extends Node
class_name TraitsSystem

var _cfg: Dictionary = {}
var _defaults: Dictionary = {}

func _ready() -> void:
    _reload()

func _reload() -> void:
    _cfg = ConfigDB.get_traits_cfg()
    var defaults_value: Variant = _cfg.get("defaults", {})
    if typeof(defaults_value) == TYPE_DICTIONARY:
        _defaults = defaults_value
    else:
        _defaults = {}

func generate_for_rarity(rarity: StringName, count: int, rng: RandomNumberGenerator = null) -> Array[StringName]:
    if rng == null:
        rng = RandomNumberGenerator.new()
        rng.randomize()
    var pools_value: Variant = _cfg.get("rarity_pools", {})
    if typeof(pools_value) != TYPE_DICTIONARY:
        return []
    var pool: Variant = pools_value.get(String(rarity), [])
    if typeof(pool) != TYPE_ARRAY:
        return []
    var bag: Array = []
    for entry in pool:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = entry.get("id", StringName(""))
        var id: StringName = _as_string_name(id_value)
        if id == StringName(""):
            continue
        var weight_value: Variant = entry.get("weight", 0.0)
        if typeof(weight_value) != TYPE_FLOAT and typeof(weight_value) != TYPE_INT:
            continue
        var weight: float = max(float(weight_value), 0.0)
        if weight <= 0.0:
            continue
        bag.append({"id": id, "weight": weight})
    if bag.is_empty():
        return []
    var draws: int = clamp(count, 0, bag.size())
    var result: Array[StringName] = []
    for _i in range(draws):
        var total_weight: float = 0.0
        for entry in bag:
            total_weight += float(entry.get("weight", 0.0))
        if total_weight <= 0.0:
            break
        var pick: float = rng.randf() * total_weight
        var acc: float = 0.0
        var chosen_index: int = 0
        for j in range(bag.size()):
            acc += float(bag[j].get("weight", 0.0))
            if pick <= acc:
                chosen_index = j
                break
        var chosen_entry: Dictionary = bag[chosen_index]
        var chosen_id: StringName = chosen_entry.get("id", StringName(""))
        if chosen_id != StringName(""):
            result.append(chosen_id)
        bag.remove_at(chosen_index)
        if bag.is_empty():
            break
    return result

func bee_has(bee_id: int, trait: StringName) -> bool:
    var bee: Dictionary = GameState.get_bee_by_id(bee_id)
    if bee.is_empty():
        return false
    var traits_value: Variant = bee.get("traits", [])
    if typeof(traits_value) != TYPE_ARRAY:
        return false
    var trait_id: StringName = _as_string_name(trait)
    if trait_id == StringName(""):
        return false
    for entry in traits_value:
        if _as_string_name(entry) == trait_id:
            return true
    return false

func build_time_bonus_seconds(bee_id: int) -> float:
    if not bee_has(bee_id, StringName("Construction")):
        return 0.0
    return _get_default_number("build_bonus_seconds", 3.0)

func repair_time_bonus_seconds(bee_id: int) -> float:
    if not bee_has(bee_id, StringName("Construction")):
        return 0.0
    return _get_default_number("repair_bonus_seconds", 3.0)

func harvest_multiplier(bee_id: int) -> float:
    if not bee_has(bee_id, StringName("Gather")):
        return 1.0
    return max(_get_default_number("gather_multiplier", 1.0), 0.0)

func _get_default_number(key: String, fallback: float) -> float:
    var value: Variant = _defaults.get(key, fallback)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return fallback

static func _as_string_name(value: Variant) -> StringName:
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        var s := String(value)
        if s.is_empty():
            return StringName("")
        return StringName(s)
    return StringName("")
