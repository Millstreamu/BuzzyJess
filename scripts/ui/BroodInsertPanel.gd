extends Control
class_name BroodInsertPanel

signal panel_closed()

@onready var _button_common: Button = $VBoxContainer/CommonButton
@onready var _button_unique: Button = $VBoxContainer/UniqueButton
@onready var _button_rare: Button = $VBoxContainer/RareButton

var _is_open: bool = false
var _cell_id: int = -1

func _ready() -> void:
    visible = false
    set_process_unhandled_input(false)
    _button_common.pressed.connect(func() -> void:
        _on_insert_pressed(StringName("Common"))
    )
    _button_unique.pressed.connect(func() -> void:
        _on_insert_pressed(StringName("Unique"))
    )
    _button_rare.pressed.connect(func() -> void:
        _on_insert_pressed(StringName("Rare"))
    )
    if typeof(Events) == TYPE_OBJECT:
        if not Events.inventory_changed.is_connected(_on_inventory_changed):
            Events.inventory_changed.connect(_on_inventory_changed)
    _update_buttons()

func is_open() -> bool:
    return _is_open

func open(cell_id: int) -> void:
    _cell_id = cell_id
    _is_open = true
    visible = true
    set_process_unhandled_input(true)
    _update_buttons()
    _button_common.grab_focus()

func close() -> void:
    if not _is_open:
        return
    _is_open = false
    visible = false
    set_process_unhandled_input(false)
    _cell_id = -1
    panel_closed.emit()

func _on_insert_pressed(tier: StringName) -> void:
    if _cell_id == -1:
        UIFx.flash_deny()
        return
    if not EggSystem.insert_egg(_cell_id, tier):
        UIFx.flash_deny()
        return
    close()

func _update_buttons() -> void:
    var counts: Dictionary = InventorySystem.snapshot()
    _update_button(_button_common, StringName("Common"), counts)
    _update_button(_button_unique, StringName("Unique"), counts)
    _update_button(_button_rare, StringName("Rare"), counts)

func _update_button(button: Button, tier: StringName, counts: Dictionary) -> void:
    var item_id: StringName = StringName("Egg" + String(tier))
    var count: int = int(counts.get(item_id, 0))
    button.text = "%s x%d" % [String(tier), count]
    button.disabled = count <= 0

func _on_inventory_changed(_snapshot: Dictionary) -> void:
    if _is_open:
        _update_buttons()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("cancel"):
        close()
        accept_event()
