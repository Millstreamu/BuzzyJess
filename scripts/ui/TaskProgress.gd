extends Control

@export var total: float = 1.0
var elapsed: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if custom_minimum_size == Vector2.ZERO:
        custom_minimum_size = Vector2(72, 72)
    size = custom_minimum_size
    pivot_offset = size * 0.5
    set_process(true)
    queue_redraw()

func setup(wait: float) -> void:
    total = max(wait, 0.0001)
    elapsed = 0.0
    if custom_minimum_size == Vector2.ZERO:
        custom_minimum_size = Vector2(72, 72)
    size = custom_minimum_size
    pivot_offset = size * 0.5
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    elapsed = min(total, elapsed + delta)
    queue_redraw()
    if elapsed >= total:
        set_process(false)

func _draw() -> void:
    var radius: float = min(size.x, size.y) * 0.5 - 4.0
    var pct: float = 1.0 if total <= 0.0 else clamp(elapsed / total, 0.0, 1.0)
    var center: Vector2 = size * 0.5
    draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU, 64, Color(1, 1, 1, 0.15), 3.0)
    draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * pct, 64, Color.WHITE, 4.0)
