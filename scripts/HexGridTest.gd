extends Node2D

@export var hex_size: float = 48.0
@export var grid_radius: int = 3
@export var hex_color: Color = Color(1.0, 0.9, 0.1)
@export var selection_color: Color = Color(1.0, 0.6, 0.0)
@export var selection_line_width: float = 4.0

var _hex_coords: Array[Vector2i] = []
var _positions: Dictionary = {}
var _selection: Vector2i = Vector2i.ZERO
var _grid_offset: Vector2 = Vector2.ZERO

const SQRT_3 := sqrt(3.0)

func _ready() -> void:
    _generate_grid()
    queue_redraw()
    var viewport := get_viewport()
    if viewport:
        viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
    _update_offset()
    queue_redraw()

func _generate_grid() -> void:
    _hex_coords.clear()
    _positions.clear()

    for q in range(-grid_radius, grid_radius + 1):
        for r in range(-grid_radius, grid_radius + 1):
            var s := -q - r
            if abs(q) <= grid_radius and abs(r) <= grid_radius and abs(s) <= grid_radius:
                var coord := Vector2i(q, r)
                _hex_coords.append(coord)
                var pos := _axial_to_pixel(coord)
                _positions[coord] = pos
    _update_offset()

func _update_offset() -> void:
    if _positions.is_empty():
        _grid_offset = Vector2.ZERO
        return

    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF
    for pos in _positions.values():
        min_x = min(min_x, pos.x)
        min_y = min(min_y, pos.y)
        max_x = max(max_x, pos.x)
        max_y = max(max_y, pos.y)

    var size := Vector2(max_x - min_x, max_y - min_y)
    var grid_center := Vector2(min_x, min_y) + size * 0.5
    _grid_offset = get_viewport_rect().size * 0.5 - grid_center

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_right"):
        _try_move_selection(Vector2i(1, 0))
    elif event.is_action_pressed("ui_left"):
        _try_move_selection(Vector2i(-1, 0))
    elif event.is_action_pressed("ui_up"):
        _try_move_selection(Vector2i(0, -1))
    elif event.is_action_pressed("ui_down"):
        _try_move_selection(Vector2i(0, 1))

func _try_move_selection(delta: Vector2i) -> void:
    var next_coord := _selection + delta
    if next_coord in _hex_coords:
        _selection = next_coord
        queue_redraw()

func _draw() -> void:
    for coord in _hex_coords:
        var center: Vector2 = _positions.get(coord, Vector2.ZERO) + _grid_offset
        var points := _hex_points(center)
        draw_colored_polygon(points, hex_color)
        if coord == _selection:
            var outline_points := points.duplicate()
            outline_points.append(outline_points[0])
            draw_polyline(outline_points, selection_color, selection_line_width)

func _axial_to_pixel(coord: Vector2i) -> Vector2:
    var q := float(coord.x)
    var r := float(coord.y)
    var x := hex_size * (SQRT_3 * q + SQRT_3 * 0.5 * r)
    var y := hex_size * (1.5 * r)
    return Vector2(x, y)

func _hex_points(center: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := PI / 6.0 + PI / 3.0 * float(i)
        var point := center + Vector2(cos(angle), sin(angle)) * hex_size
        points.append(point)
    return points
