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

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    option_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    start_button.pressed.connect(_on_start_pressed)
    cancel_button.pressed.connect(close)
    set_process(false)
    set_process_unhandled_input(true)
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

func close() -> void:
    if not _is_open:
        return
    _is_open = false
    visible = false
    set_process(false)
    _cell_id = -1
    _end_time = 0.0

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
    if event.is_action_pressed("cancel"):
        close()
        accept_event()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var rect: Rect2 = option_layer.get_global_rect()
        if rect.has_point(event.position):
            return
        close()
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
*** End EOF
