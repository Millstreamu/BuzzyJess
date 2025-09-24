# -----------------------------------------------------------------------------
# File: scripts/ui/RadialCandleHall.gd
# Purpose: Candle Hall ritual radial selector with progress feedback
# Depends: InputActions, CandleHallSystem, UIFx, Events
# Notes: Shows ritual timers and supports keyboard focus cycling
# -----------------------------------------------------------------------------

## RadialCandleHall
## Handles Candle Hall ritual activation flow and UI updates.
extends Control
class_name RadialCandleHall

@export var offset_radius: float = 72.0
@export var padding: Vector2 = Vector2(120, 140)

@onready var option_layer: Control = $OptionLayer
@onready var start_button: Button = $OptionLayer/StartButton
@onready var cancel_button: Button = $OptionLayer/CancelButton
@onready var status_label: Label = $OptionLayer/Status

var _cell_id: int = -1
var _is_open: bool = false
var _end_time: float = 0.0
var _focus_index: int = 0
var _focus_buttons: Array[Button] = []

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    option_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    start_button.pressed.connect(_on_start_pressed)
    cancel_button.pressed.connect(close)
    set_process(false)
    set_process_unhandled_input(true)
    focus_mode = Control.FOCUS_ALL
    _focus_buttons = []
    if start_button:
        start_button.focus_mode = Control.FOCUS_ALL
        start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _focus_buttons.append(start_button)
    if cancel_button:
        cancel_button.focus_mode = Control.FOCUS_ALL
        cancel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _focus_buttons.append(cancel_button)
    if typeof(Events) == TYPE_OBJECT:
        if not Events.resources_changed.is_connected(_on_state_changed):
            Events.resources_changed.connect(_on_state_changed)
        if not Events.inventory_changed.is_connected(_on_state_changed):
            Events.inventory_changed.connect(_on_state_changed)
        if not Events.ability_added.is_connected(_on_state_changed):
            Events.ability_added.connect(_on_state_changed)
        if not Events.ability_removed.is_connected(_on_state_changed):
            Events.ability_removed.connect(_on_state_changed)
        if not Events.ritual_started.is_connected(_on_ritual_started):
            Events.ritual_started.connect(_on_ritual_started)
        if not Events.ritual_completed.is_connected(_on_ritual_completed):
            Events.ritual_completed.connect(_on_ritual_completed)

func open_for_cell(cell_id: int, world_pos: Vector2) -> void:
    _cell_id = cell_id
    _is_open = true
    visible = true
    move_to_front()
    var canvas_pos: Vector2 = _to_canvas_position(world_pos)
    _position_option_layer(canvas_pos)
    _refresh_state()
    set_process(true)
    _focus_first_available()

func close() -> void:
    if not _is_open:
        return
    _is_open = false
    visible = false
    set_process(false)
    _cell_id = -1
    _end_time = 0.0
    _focus_index = 0

func is_open() -> bool:
    return _is_open

func _on_start_pressed() -> void:
    if _cell_id < 0:
        UIFx.flash_deny()
        return
    if not CandleHallSystem.start_ritual(_cell_id):
        _refresh_state()
        return
    close()

func _refresh_state() -> void:
    if _cell_id < 0:
        return
    var cfg: Dictionary = ConfigDB.abilities_ritual_cfg()
    var comb_cost: int = int(round(float(cfg.get("comb_cost", 0))))
    if comb_cost > 0:
        start_button.text = "Start Ritual (-%d Comb)" % comb_cost
    else:
        start_button.text = "Start Ritual"
    var active: bool = CandleHallSystem.is_ritual_active(_cell_id)
    if active:
        _end_time = CandleHallSystem.ritual_end_time(_cell_id)
        start_button.disabled = true
        status_label.text = _format_time_left()
        return
    _end_time = 0.0
    if AbilitySystem.at_capacity():
        start_button.disabled = true
        status_label.text = "Abilities full"
        return
    var spend_cost: Dictionary = {}
    if comb_cost > 0:
        spend_cost[StringName("Comb")] = comb_cost
    if not GameState.can_spend(spend_cost):
        start_button.disabled = true
        status_label.text = "Requires %d Comb" % comb_cost
        return
    start_button.disabled = false
    status_label.text = ""
    _ensure_focus_valid()

func _format_time_left() -> String:
    if _end_time <= 0.0:
        return "Ritual in progress"
    var remaining: float = max(_end_time - Time.get_unix_time_from_system(), 0.0)
    if remaining <= 0.5:
        return "Ritual finishing"
    return "In progress (%.0fs)" % ceil(remaining)

func _position_option_layer(center: Vector2) -> void:
    var size: Vector2 = option_layer.size
    if size == Vector2.ZERO:
        size = option_layer.get_combined_minimum_size()
        if size == Vector2.ZERO:
            size = Vector2(200, 160)
    option_layer.size = size
    option_layer.position = center - size * 0.5
    _clamp_option_layer()

func _clamp_option_layer() -> void:
    var rect: Rect2i = get_viewport_rect()
    var pos: Vector2 = option_layer.position
    var size: Vector2 = option_layer.size
    if size == Vector2.ZERO:
        size = option_layer.get_combined_minimum_size()
    var min_x: float = padding.x
    var max_x: float = rect.size.x - padding.x - size.x
    if max_x < min_x:
        max_x = min_x
    var min_y: float = padding.y
    var max_y: float = rect.size.y - padding.y - size.y
    if max_y < min_y:
        max_y = min_y
    option_layer.position = Vector2(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))

func _to_canvas_position(world_pos: Vector2) -> Vector2:
    var viewport: Viewport = get_viewport()
    if viewport:
        var camera: Camera2D = viewport.get_camera_2d()
        if camera:
            return camera.unproject_position(world_pos)
    return world_pos

func _process(_delta: float) -> void:
    if not _is_open:
        return
    if _cell_id < 0:
        return
    if CandleHallSystem.is_ritual_active(_cell_id):
        _end_time = CandleHallSystem.ritual_end_time(_cell_id)
        status_label.text = _format_time_left()
    else:
        if _end_time > 0.0:
            _refresh_state()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed(InputActions.CANCEL):
        close()
        accept_event()
    elif event.is_action_pressed(InputActions.CONFIRM):
        if _activate_current():
            accept_event()
    elif event.is_action_pressed(InputActions.UI_RIGHT) or event.is_action_pressed(InputActions.UI_DOWN):
        _move_focus(1)
        accept_event()
    elif event.is_action_pressed(InputActions.UI_LEFT) or event.is_action_pressed(InputActions.UI_UP):
        _move_focus(-1)
        accept_event()

func _on_state_changed(_data: Variant = null) -> void:
    if not _is_open:
        return
    _refresh_state()

func _on_ritual_started(cell_id: int, ends_at: float) -> void:
    if cell_id != _cell_id:
        return
    _end_time = ends_at
    _refresh_state()

func _on_ritual_completed(cell_id: int, _ability_id: StringName) -> void:
    if cell_id != _cell_id:
        return
    _end_time = 0.0
    _refresh_state()

func _ensure_focus_valid() -> void:
    if not _is_open:
        return
    var current := _current_focus_button()
    if _can_focus(current):
        current.grab_focus()
        return
    _focus_first_available()

func _focus_first_available() -> void:
    if not _is_open:
        return
    if _focus_buttons.is_empty():
        return
    var count := _focus_buttons.size()
    for i in range(count):
        var idx := (i + _focus_index) % count
        var button := _focus_buttons[idx]
        if _can_focus(button):
            _focus_index = idx
            button.grab_focus()
            return
    var fallback := _current_focus_button()
    if fallback:
        fallback.grab_focus()

func _move_focus(delta: int) -> void:
    if _focus_buttons.is_empty():
        return
    var count := _focus_buttons.size()
    var idx := _focus_index
    for _i in range(count):
        idx = wrapi(idx + delta, 0, count)
        var button := _focus_buttons[idx]
        if _can_focus(button):
            _focus_index = idx
            button.grab_focus()
            return
    var current := _current_focus_button()
    if current:
        current.grab_focus()

func _activate_current() -> bool:
    var button := _current_focus_button()
    if not _can_focus(button):
        UIFx.flash_deny()
        return false
    button.emit_signal("pressed")
    return true

func _current_focus_button() -> Button:
    if _focus_buttons.is_empty():
        return null
    _focus_index = clamp(_focus_index, 0, _focus_buttons.size() - 1)
    var button := _focus_buttons[_focus_index]
    if button != null and button.is_inside_tree():
        return button
    return null

func _can_focus(button: Button) -> bool:
    return button != null and button.visible and not button.disabled

