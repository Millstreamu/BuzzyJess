extends Control
class_name QueenFeedPanel

signal panel_closed()

@onready var _button_common: Button = $VBoxContainer/CommonButton
@onready var _button_unique: Button = $VBoxContainer/UniqueButton
@onready var _button_rare: Button = $VBoxContainer/RareButton

var _is_open: bool = false

func _ready() -> void:
    visible = false
    set_process_unhandled_input(false)
    _button_common.pressed.connect(func() -> void:
        _on_feed_pressed(StringName("Common"))
    )
    _button_unique.pressed.connect(func() -> void:
        _on_feed_pressed(StringName("Unique"))
    )
    _button_rare.pressed.connect(func() -> void:
        _on_feed_pressed(StringName("Rare"))
    )
    if typeof(Events) == TYPE_OBJECT:
        if not Events.resources_changed.is_connected(_on_resources_changed):
            Events.resources_changed.connect(_on_resources_changed)
    _update_buttons()

func is_open() -> bool:
    return _is_open

func open() -> void:
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
    panel_closed.emit()

func _on_feed_pressed(tier: StringName) -> void:
    if not EggSystem.feed_queen(tier):
        return
    close()

func _update_buttons() -> void:
    _update_button(_button_common, StringName("Common"))
    _update_button(_button_unique, StringName("Unique"))
    _update_button(_button_rare, StringName("Rare"))

func _update_button(button: Button, tier: StringName) -> void:
    var cost: Dictionary = ConfigDB.eggs_get_feed_cost(tier)
    var label: String = String(tier)
    if not cost.is_empty():
        var parts: Array[String] = []
        for key in cost.keys():
            parts.append("%d %s" % [int(cost[key]), String(key)])
        label += " (" + ", ".join(parts) + ")"
    button.text = label
    button.disabled = not GameState.can_afford(cost)

func _on_resources_changed(_snapshot: Dictionary) -> void:
    if _is_open:
        _update_buttons()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("cancel"):
        close()
        accept_event()
