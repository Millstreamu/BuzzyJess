extends Control
class_name ThreatResolvePanel

@export var hold_ms_result := 1500
@export var hold_ms_next := 1200

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var result_txt: Label = $"VBoxContainer/ResultBox/ResultText"
@onready var anim_slot: Control = $"VBoxContainer/ResultBox/AnimSlot"
@onready var defense_val: Label = $"VBoxContainer/Stats/DefenseVal"
@onready var power_val: Label = $"VBoxContainer/Stats/PowerVal"
@onready var next_name: Label = $"VBoxContainer/NextBox/NextName"
@onready var next_time: Label = $"VBoxContainer/NextBox/NextTime"

var _next_end_time: float = -1.0
var _next_id: StringName = &""
var _sequence_token: int = 0
var _next_timer: Timer
var _next_preview_active: bool = false
var _hidden_position: float = 0.0
var _visible_position: float = -240.0

func _ready() -> void:
    visible = false
    result_txt.scale = Vector2.ONE
    anim_slot.scale = Vector2.ONE
    if anim and not anim.animation_finished.is_connected(_on_animation_finished):
        anim.animation_finished.connect(_on_animation_finished)
    if not resized.is_connected(_on_resized):
        resized.connect(_on_resized)
    if typeof(Events) == TYPE_OBJECT:
        if not Events.threat_resolved.is_connected(_on_resolved):
            Events.threat_resolved.connect(_on_resolved)
        if not Events.threat_warning_started.is_connected(_on_next_threat):
            Events.threat_warning_started.connect(_on_next_threat)
    call_deferred("_configure_slide_animations")

func _on_resized() -> void:
    _configure_slide_animations()

func _configure_slide_animations() -> void:
    var panel_height := size.y
    if panel_height <= 0.0:
        panel_height = max(get_combined_minimum_size().y, 1.0)
    _hidden_position = 0.0
    _visible_position = -panel_height
    if not visible:
        position.y = _hidden_position
    result_txt.pivot_offset = result_txt.size * 0.5
    anim_slot.pivot_offset = anim_slot.size * 0.5
    var slide_up_anim := anim.get_animation("slide_up")
    if slide_up_anim:
        var track := slide_up_anim.find_track(NodePath("."), Animation.TYPE_VALUE, StringName("position:y"))
        if track != -1:
            slide_up_anim.track_set_key_value(track, 0, _hidden_position)
            slide_up_anim.track_set_key_value(track, 1, _visible_position)
    var slide_down_anim := anim.get_animation("slide_down")
    if slide_down_anim:
        var track_down := slide_down_anim.find_track(NodePath("."), Animation.TYPE_VALUE, StringName("position:y"))
        if track_down != -1:
            slide_down_anim.track_set_key_value(track_down, 0, _visible_position)
            slide_down_anim.track_set_key_value(track_down, 1, _hidden_position)

func _on_resolved(id: StringName, success: bool, power: int, defense: int) -> void:
    _sequence_token += 1
    _stop_next_countdown()
    _fill_result(success, power, defense)
    _next_id = &""
    _next_end_time = -1.0
    _clear_next_box()
    _slide_up_then_show(_sequence_token)

func _fill_result(success: bool, power: int, defense: int) -> void:
    result_txt.text = "DEFENDED" if success else "DESTROYED"
    result_txt.modulate = Color(0.2, 0.8, 0.2) if success else Color(0.9, 0.2, 0.2)
    defense_val.text = "Defense %d" % defense
    power_val.text = "vs Power %d" % power

func _on_next_threat(id: StringName, _power: int, end_time: float) -> void:
    _next_id = id
    _next_end_time = end_time
    if id.is_empty():
        next_name.text = "—"
    else:
        var display_name := ConfigDB.get_threat_display_name(id) if typeof(ConfigDB) == TYPE_OBJECT else str(id).capitalize()
        next_name.text = "Next: %s" % display_name
    if _next_preview_active:
        _start_next_countdown(_sequence_token)

func _slide_up_then_show(token: int) -> void:
    visible = true
    position.y = _hidden_position
    anim.stop()
    anim.play("slide_up")
    anim.queue("pulse")
    _play_placeholder_anim()
    var result_timer := get_tree().create_timer(float(hold_ms_result) / 1000.0)
    await result_timer.timeout
    if token != _sequence_token:
        return
    if _next_end_time > 0.0:
        _next_preview_active = true
        _start_next_countdown(token)
        var next_timer := get_tree().create_timer(float(hold_ms_next) / 1000.0)
        await next_timer.timeout
        if token != _sequence_token:
            return
    _next_preview_active = false
    anim.play("slide_down")

func _start_next_countdown(token: int) -> void:
    if token != _sequence_token:
        return
    if _next_end_time <= 0.0:
        return
    if _next_id.is_empty():
        return
    _update_next_time()
    if _next_timer == null:
        _next_timer = Timer.new()
        _next_timer.wait_time = 0.2
        _next_timer.one_shot = false
        add_child(_next_timer)
        _next_timer.timeout.connect(_on_next_timer_timeout)
    if not _next_timer.is_stopped():
        _next_timer.stop()
    _next_timer.start()

func _update_next_time() -> void:
    if _next_end_time <= 0.0:
        next_time.text = ""
        return
    var now := Time.get_unix_time_from_system()
    var left := max(0.0, _next_end_time - now)
    var minutes := int(left) / 60
    var seconds := int(left) % 60
    next_time.text = " in %02d:%02d" % [minutes, seconds]
    if left <= 0.0:
        _next_end_time = 0.0
        _stop_next_countdown(false)

func _on_next_timer_timeout() -> void:
    if _next_end_time <= 0.0:
        _stop_next_countdown()
        return
    _update_next_time()

func _stop_next_countdown(clear_text: bool = true) -> void:
    if _next_timer:
        _next_timer.stop()
        _next_timer.queue_free()
        _next_timer = null
    if clear_text:
        next_time.text = ""
        _next_preview_active = false

func _clear_next_box() -> void:
    next_name.text = "—"
    next_time.text = ""

func _play_placeholder_anim() -> void:
    anim_slot.scale = Vector2.ONE
    var tween := create_tween()
    tween.tween_property(anim_slot, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(anim_slot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_animation_finished(name: StringName) -> void:
    if name == StringName("slide_down"):
        visible = false
        position.y = _hidden_position
        _stop_next_countdown()
        _clear_next_box()

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if typeof(Events) == TYPE_OBJECT:
            if Events.threat_resolved.is_connected(_on_resolved):
                Events.threat_resolved.disconnect(_on_resolved)
            if Events.threat_warning_started.is_connected(_on_next_threat):
                Events.threat_warning_started.disconnect(_on_next_threat)
        _stop_next_countdown()
