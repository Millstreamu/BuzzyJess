extends Node
class_name BuffsSystem

var _buffs: Dictionary = {}
var _next_id: int = 1

func _ready() -> void:
    _buffs.clear()
    _next_id = 1

func clear() -> void:
    _buffs.clear()
    _next_id = 1

func apply_temporary_buff(target: StringName, mult: float, duration: float) -> void:
    target = target if typeof(target) == TYPE_STRING_NAME else StringName(String(target))
    if target == StringName(""):
        return
    if mult <= 0.0:
        return
    _cleanup_target(target)
    var buff_id: int = _next_id
    _next_id += 1
    var ends_at: float = Time.get_unix_time_from_system() + max(duration, 0.0)
    var entry: Dictionary = {
        "id": buff_id,
        "mult": mult,
        "ends_at": ends_at
    }
    var list: Array = _buffs.get(target, [])
    list.append(entry)
    _buffs[target] = list
    if duration > 0.0:
        var timer := get_tree().create_timer(max(duration, 0.01))
        if timer:
            timer.timeout.connect(func() -> void:
                _expire_buff(target, buff_id)
            , CONNECT_ONE_SHOT)

func get_mult(target: StringName) -> float:
    target = target if typeof(target) == TYPE_STRING_NAME else StringName(String(target))
    if target == StringName(""):
        return 1.0
    _cleanup_target(target)
    var list: Array = _buffs.get(target, [])
    if list.is_empty():
        return 1.0
    var total: float = 1.0
    for entry in list:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var mult_value: Variant = entry.get("mult", 1.0)
        if typeof(mult_value) == TYPE_FLOAT or typeof(mult_value) == TYPE_INT:
            total *= float(mult_value)
    return total

func _expire_buff(target: StringName, buff_id: int) -> void:
    if not _buffs.has(target):
        return
    var list: Array = _buffs.get(target, [])
    for i in range(list.size() - 1, -1, -1):
        var entry: Dictionary = list[i]
        if int(entry.get("id", -1)) == buff_id:
            list.remove_at(i)
            break
    if list.is_empty():
        _buffs.erase(target)
    else:
        _buffs[target] = list

func _cleanup_target(target: StringName) -> void:
    if not _buffs.has(target):
        return
    var list: Array = _buffs.get(target, [])
    if list.is_empty():
        _buffs.erase(target)
        return
    var now: float = Time.get_unix_time_from_system()
    for i in range(list.size() - 1, -1, -1):
        var entry: Dictionary = list[i]
        var ends_value: Variant = entry.get("ends_at", 0.0)
        var ends_at: float = 0.0
        if typeof(ends_value) == TYPE_FLOAT or typeof(ends_value) == TYPE_INT:
            ends_at = float(ends_value)
        if ends_at <= now:
            list.remove_at(i)
    if list.is_empty():
        _buffs.erase(target)
    else:
        _buffs[target] = list
*** End EOF
