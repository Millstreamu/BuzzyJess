extends Node
class_name InventorySystem

var _items: Dictionary = {}
var _item_ids: Array[StringName] = []

func _ready() -> void:
    reset()

func reset() -> void:
    _items.clear()
    _item_ids = ConfigDB.get_item_ids()
    for id in _item_ids:
        _items[String(id)] = 0
    _emit_changed()

func get_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    for key in _items.keys():
        snapshot[StringName(key)] = int(_items[key])
    return snapshot

func add_item(item_id: StringName, amount: int) -> void:
    if amount <= 0:
        return
    var key: String = String(item_id)
    var current: int = int(_items.get(key, 0))
    _items[key] = max(0, current + amount)
    _emit_changed()

func remove_item(item_id: StringName, amount: int) -> bool:
    if amount <= 0:
        return true
    var key: String = String(item_id)
    var current: int = int(_items.get(key, 0))
    if current < amount:
        return false
    _items[key] = max(0, current - amount)
    _emit_changed()
    return true

func has_item(item_id: StringName, amount: int = 1) -> bool:
    if amount <= 0:
        return true
    var key: String = String(item_id)
    return int(_items.get(key, 0)) >= amount

func get_count(item_id: StringName) -> int:
    return int(_items.get(String(item_id), 0))

func set_count(item_id: StringName, amount: int) -> void:
    var key: String = String(item_id)
    _items[key] = max(0, amount)
    _emit_changed()

func _emit_changed() -> void:
    if typeof(Events) == TYPE_OBJECT:
        Events.inventory_changed.emit(get_snapshot())
