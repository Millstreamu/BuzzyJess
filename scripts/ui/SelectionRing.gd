extends Control

@export var ring_color: Color = Color.WHITE
@export var ring_width: float = 3.0
@export var pulse_scale: float = 0.05
@export var pulse_duration: float = 0.6

var _pulse_tween: Tween

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    pivot_offset = size * 0.5
    _start_pulse()
    queue_redraw()

func _start_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    scale = Vector2.ONE
    _pulse_tween = create_tween()
    _pulse_tween.set_loops()
    _pulse_tween.tween_property(self, "scale", Vector2.ONE * (1.0 + pulse_scale), pulse_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
        _pulse_tween = null
    scale = Vector2.ONE
    queue_redraw()

func _draw() -> void:
    var radius := min(size.x, size.y) * 0.5 - ring_width * 0.5
    draw_arc(pivot_offset, radius, 0.0, TAU, 96, ring_color, ring_width)
