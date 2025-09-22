extends RefCounted
class_name BeeModel

var id: int = 0
var rarity: StringName = &"Common"
var traits: Array[StringName] = []

func set_traits(values: Array) -> void:
    traits.clear()
    var seen: Dictionary = {}
    for value in values:
        var trait_id := _to_string_name(value)
        if trait_id == StringName(""):
            continue
        if seen.has(trait_id):
            continue
        seen[trait_id] = true
        traits.append(trait_id)

func to_dict() -> Dictionary:
    return {
        "id": id,
        "rarity": rarity,
        "traits": traits.duplicate(true)
    }

static func _to_string_name(value: Variant) -> StringName:
    if typeof(value) == TYPE_STRING_NAME:
        return value
    if typeof(value) == TYPE_STRING:
        var s := String(value)
        if s.is_empty():
            return StringName("")
        return StringName(s)
    if typeof(value) == TYPE_DICTIONARY:
        var dict: Dictionary = value
        if dict.has("id"):
            return _to_string_name(dict.get("id"))
        if dict.has("trait"):
            return _to_string_name(dict.get("trait"))
        if dict.has("trait_id"):
            return _to_string_name(dict.get("trait_id"))
    return StringName("")
