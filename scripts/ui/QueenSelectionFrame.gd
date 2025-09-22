extends Control
class_name QueenSelectionFrame

@export var outer_border_color: Color = Color(0.08, 0.05, 0.02, 1.0)
@export var inner_border_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outer_border_width: int = 3
@export var inner_border_width: int = 2
@export var corner_radius: int = 26
@export var inset: float = 6.0

var _outer_style: StyleBoxFlat
var _inner_style: StyleBoxFlat

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_styles()
    pivot_offset = size * 0.5
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        pivot_offset = size * 0.5
        queue_redraw()

func _build_styles() -> void:
    _outer_style = StyleBoxFlat.new()
    _outer_style.bg_color = Color(0, 0, 0, 0)
    _outer_style.set_border_width_all(max(outer_border_width, 0))
    _outer_style.border_color = outer_border_color
    _outer_style.set_corner_radius_all(max(corner_radius, 0))

    _inner_style = StyleBoxFlat.new()
    _inner_style.bg_color = Color(0, 0, 0, 0)
    _inner_style.set_border_width_all(max(inner_border_width, 0))
    _inner_style.border_color = inner_border_color
    var inner_radius: int = max(corner_radius - 4, 0)
    _inner_style.set_corner_radius_all(inner_radius)

func _draw() -> void:
    if size.x <= 0 or size.y <= 0:
        return
    if _outer_style == null or _inner_style == null:
        _build_styles()
    draw_style_box(_outer_style, Rect2(Vector2.ZERO, size))
    var inset_vec := Vector2(inset, inset)
    var inner_rect := Rect2(inset_vec, size - inset_vec * 2.0)
    if inner_rect.size.x <= 0 or inner_rect.size.y <= 0:
        return
    draw_style_box(_inner_style, inner_rect)
