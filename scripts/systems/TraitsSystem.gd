extends Node
class_name TraitsSystem

const DEFAULT_TRAITS := [
    {"id": StringName("Construction"), "name": "Construction", "desc": "Shortens build and repair tasks."},
    {"id": StringName("Gather"), "name": "Gather", "desc": "Improves gathering output."},
    {"id": StringName("Brewer"), "name": "Brewer", "desc": "Specialises in honey vats."}
]

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()

func generate(count: int) -> Array:
    if count <= 0:
        return []
    var pool: Array = []
    for entry in DEFAULT_TRAITS:
        pool.append(entry.duplicate(true))
    var result: Array = []
    var remaining: int = min(count, pool.size())
    while remaining > 0 and not pool.is_empty():
        var index: int = _rng.randi_range(0, pool.size() - 1)
        var trait: Dictionary = pool.pop_at(index)
        result.append(trait)
        remaining -= 1
    return result

func bee_has_trait(bee: Dictionary, trait_id: StringName) -> bool:
    var traits_value: Variant = bee.get("traits", [])
    if typeof(traits_value) != TYPE_ARRAY:
        return false
    for value in traits_value:
        if typeof(value) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = value.get("id", StringName(""))
        if typeof(id_value) == TYPE_STRING_NAME and id_value == trait_id:
            return true
        if typeof(id_value) == TYPE_STRING and StringName(String(id_value)) == trait_id:
            return true
    return false

