extends Node

var _items: Dictionary = {}

func _ready() -> void:
    _items.clear()

func load_from_save(data: Dictionary) -> void:
    var source: Variant = data.get("inventory", {})
    _items.clear()
    if typeof(source) == TYPE_DICTIONARY:
        for key in source.keys():
            var id := StringName(String(key))
            var amount: Variant = source.get(key, 0)
            if typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT:
                _items[id] = int(amount)
    _emit_changed()

func to_save() -> Dictionary:
    var save_data: Dictionary = {}
    for key in _items.keys():
        save_data[String(key)] = int(_items[key])
    return {"inventory": save_data}

func add_item(id: StringName, qty: int = 1) -> void:
    if qty <= 0:
        return
    var current: int = int(_items.get(id, 0))
    _items[id] = current + qty
    _emit_changed()

func remove_item(id: StringName, qty: int = 1) -> bool:
    var have: int = int(_items.get(id, 0))
    if qty <= 0 or have < qty:
        return false
    var left: int = have - qty
    if left <= 0:
        _items.erase(id)
    else:
        _items[id] = left
    _emit_changed()
    return true

func count(id: StringName) -> int:
    return int(_items.get(id, 0))

func has(id: StringName, qty: int = 1) -> bool:
    return count(id) >= qty

func snapshot() -> Dictionary:
    return _items.duplicate(true)

func _emit_changed() -> void:
    if typeof(Events) == TYPE_OBJECT:
        Events.inventory_changed.emit(snapshot())
