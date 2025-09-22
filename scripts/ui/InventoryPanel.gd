extends Control
class_name InventoryPanel

@onready var _common_label: Label = $VBoxContainer/CommonLabel
@onready var _unique_label: Label = $VBoxContainer/UniqueLabel
@onready var _rare_label: Label = $VBoxContainer/RareLabel

func _ready() -> void:
    if typeof(Events) == TYPE_OBJECT:
        if not Events.inventory_changed.is_connected(_on_inventory_changed):
            Events.inventory_changed.connect(_on_inventory_changed)
    _on_inventory_changed(InventorySystem.get_snapshot())

func _on_inventory_changed(snapshot: Dictionary) -> void:
    _common_label.text = _format_entry(StringName("EggCommon"), "Common", snapshot)
    _unique_label.text = _format_entry(StringName("EggUnique"), "Unique", snapshot)
    _rare_label.text = _format_entry(StringName("EggRare"), "Rare", snapshot)

func _format_entry(item_id: StringName, label: String, snapshot: Dictionary) -> String:
    var count: int = int(snapshot.get(item_id, 0))
    return "%s: %d" % [label, count]
