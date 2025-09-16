extends Control
class_name BuildRadialMenu

signal option_chosen(type: StringName)
signal cancelled

class BuildOption:
    var type: StringName
    var label: String
    var icon: Texture2D
    var cost: Dictionary
    var enabled: bool = true
    func _init(t, l := "", i := null, c := {}, e := true):
        type = t
        label = l
        icon = i
        cost = c
        enabled = e

var _options: Array[BuildOption] = []
var _selected := 0
var _radius := 72.0
var _start_angle_deg := -90.0
var _is_open := false

@onready var ring: Control = $Ring

func open_at(pos_screen: Vector2, options: Array[BuildOption], radius := 72.0, start_angle_deg := -90.0) -> void:
    _options = options
    _radius = radius
    _start_angle_deg = start_angle_deg
    global_position = pos_screen
    scale = Vector2.ZERO
    _build_bubbles()
    _animate_open()
    _is_open = true
    _selected = _default_index()
    _update_highlight()

func close_and_free(emit_cancel := false) -> void:
    _animate_close(func():
        if emit_cancel:
            cancelled.emit()
        queue_free())

func _default_index() -> int:
    for i in _options.size():
        if _options[i].enabled:
            return i
    return 0

func _build_bubbles() -> void:
    for c in ring.get_children():
        c.queue_free()
    var positions := compute_positions(_options.size(), _radius, _start_angle_deg)
    for i in _options.size():
        var opt := _options[i]
        var btn := Button.new()
        btn.text = opt.label
        btn.disabled = !opt.enabled
        btn.position = Vector2.ZERO
        btn.pivot_offset = btn.size * 0.5
        ring.add_child(btn)
        var tw := get_tree().create_tween()
        tw.set_trans(Tween.TRANS_SINE)
        tw.tween_property(btn, "position", positions[i], 0.2).from(Vector2.ZERO).set_delay(i * 0.02)
        tw.parallel().tween_property(btn, "modulate:a", 1.0, 0.2).from(0.0).set_delay(i * 0.02)

func compute_positions(n: int, r: float, start_deg: float) -> Array:
    var pts: Array = []
    if n <= 0:
        return pts
    for i in n:
        var ang := deg_to_rad(start_deg + 360.0 / n * i)
        pts.append(Vector2(cos(ang), sin(ang)) * r)
    return pts

func _unhandled_input(event: InputEvent) -> void:
    if !_is_open:
        return
    var dir := Vector2.ZERO
    if event.is_action_pressed("ui_right"):
        dir = Vector2.RIGHT
    elif event.is_action_pressed("ui_left"):
        dir = Vector2.LEFT
    elif event.is_action_pressed("ui_down"):
        dir = Vector2.DOWN
    elif event.is_action_pressed("ui_up"):
        dir = Vector2.UP
    if dir != Vector2.ZERO:
        _select_closest(dir)
        _update_highlight()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("confirm"):
        var opt := _options[_selected]
        if opt.enabled:
            option_chosen.emit(opt.type)
            close_and_free(false)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cancel"):
        close_and_free(true)
        get_viewport().set_input_as_handled()

func _select_closest(dir: Vector2) -> void:
    var best := _selected
    var best_dot := -1.0
    for i in _options.size():
        var btn := ring.get_child(i)
        var v := btn.position.normalized()
        var d := dir.dot(v)
        if d > best_dot:
            best_dot = d
            best = i
    _selected = best

func _update_highlight() -> void:
    for i in ring.get_child_count():
        var btn: Button = ring.get_child(i)
        if i == _selected:
            btn.scale = Vector2.ONE * 1.2
        else:
            btn.scale = Vector2.ONE
        if btn.disabled:
            btn.modulate = Color(0.6, 0.6, 0.6)
        else:
            btn.modulate = Color.WHITE

func _animate_open() -> void:
    var tw := create_tween()
    tw.tween_property(self, "scale", Vector2.ONE, 0.2).from(Vector2.ZERO)

func _animate_close(cb: Callable) -> void:
    var tw := create_tween()
    tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
    tw.finished.connect(cb)
