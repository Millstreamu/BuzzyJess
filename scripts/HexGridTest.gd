extends Node2D

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")
const FloatingTextScene := preload("res://scenes/FX/FloatingText.tscn")

@export var hex_size: float = 48.0
@export var grid_radius: int = 3
@export var hex_color: Color = Color(1.0, 0.9, 0.1)
@export var selection_color: Color = Color(1.0, 0.6, 0.0)
@export var selection_line_width: float = 4.0

var _hex_coords: Array[Vector2i] = []
var _positions: Dictionary = {}
var _cell_ids_by_coord: Dictionary = {}
var _coords_by_id: Dictionary = {}
var _selection: Vector2i = Vector2i.ZERO
var _grid_offset: Vector2 = Vector2.ZERO

const SQRT_3 := sqrt(3.0)

var _cell_type_colors := {
    "Empty": Color(1.0, 0.9, 0.1),
    "Brood": Color(0.8, 0.4, 0.4),
    "Storage": Color(0.7, 0.7, 0.2),
    "HoneyVat": Color(0.9, 0.7, 0.3),
    "WaxWorkshop": Color(0.7, 0.5, 0.3),
    "CandleHall": Color(0.6, 0.5, 0.9),
    "GuardPost": Color(0.4, 0.6, 0.8),
    "GatheringHut": Color(0.5, 0.8, 0.5),
    "Damage": Color(0.25, 0.23, 0.28)
}

@onready var _build_controller: BuildController = $BuildController
@onready var _assign_controller: AssignController = $AssignController
@onready var _gathering_controller: GatheringController = $GatheringController
@onready var _build_menu: BuildRadialMenu = $CanvasLayer/BuildRadialMenu
@onready var _resources_panel: ResourcesPanel = $CanvasLayer/ResourcesPanel

func _ready() -> void:
    _generate_grid()
    if not Events.cell_built.is_connected(_on_cell_built):
        Events.cell_built.connect(_on_cell_built)
    if not Events.assignment_changed.is_connected(_on_assignment_changed):
        Events.assignment_changed.connect(_on_assignment_changed)
    if not Events.production_tick.is_connected(_on_production_tick):
        Events.production_tick.connect(_on_production_tick)
    if not Events.cell_converted.is_connected(_on_cell_converted):
        Events.cell_converted.connect(_on_cell_converted)
    if not Events.harvest_tick.is_connected(_on_harvest_tick):
        Events.harvest_tick.connect(_on_harvest_tick)
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
    _cell_ids_by_coord.clear()
    _coords_by_id.clear()
    HiveSystem.reset()

    var cell_id := 0

    for q in range(-grid_radius, grid_radius + 1):
        for r in range(-grid_radius, grid_radius + 1):
            var s := -q - r
            if abs(q) <= grid_radius and abs(r) <= grid_radius and abs(s) <= grid_radius:
                var coord := Vector2i(q, r)
                _hex_coords.append(coord)
                var pos := _axial_to_pixel(coord)
                _positions[coord] = pos
                _cell_ids_by_coord[coord] = cell_id
                _coords_by_id[cell_id] = coord
                HiveSystem.register_cell(cell_id, {
                    "coord": coord,
                    "type": "Empty"
                })
                cell_id += 1
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
    if event.is_action_pressed("gather_panel_toggle"):
        if _gathering_controller:
            _gathering_controller.toggle_panel()
        var viewport_toggle := get_viewport()
        if viewport_toggle:
            viewport_toggle.set_input_as_handled()
        return

    if event.is_action_pressed("resources_panel_toggle"):
        if _resources_panel:
            _resources_panel.toggle()
        var viewport := get_viewport()
        if viewport:
            viewport.set_input_as_handled()
        return

    if (_build_menu and _build_menu.is_open()) or (_assign_controller and _assign_controller.is_panel_open()) or (_resources_panel and _resources_panel.is_open()) or (_gathering_controller and _gathering_controller.is_panel_open()):
        return

    if event.is_action_pressed("ui_right"):
        _try_move_selection(Vector2i(1, 0))
    elif event.is_action_pressed("ui_left"):
        _try_move_selection(Vector2i(-1, 0))
    elif event.is_action_pressed("ui_up"):
        _try_move_selection(Vector2i(0, -1))
    elif event.is_action_pressed("ui_down"):
        _try_move_selection(Vector2i(0, 1))
    elif event.is_action_pressed("confirm"):
        _handle_confirm()

func _try_move_selection(delta: Vector2i) -> void:
    var next_coord := _selection + delta
    if _positions.has(next_coord):
        _selection = next_coord
        queue_redraw()

func _handle_confirm() -> void:
    var cell_id: int = _cell_ids_by_coord.get(_selection, -1)
    if cell_id == -1:
        return
    var cell_type := HiveSystem.get_cell_type(cell_id)
    if cell_type == "Empty":
        if _build_controller:
            var world_position: Vector2 = _get_cell_center(_selection)
            _build_controller.open_radial(cell_id, world_position)
    else:
        var cell_type_name: StringName = StringName(cell_type)
        if not ConfigDB.is_cell_assignable(cell_type_name):
            UIFx.flash_deny()
            return
        if _assign_controller:
            _assign_controller.open_panel(cell_id)

func _draw_bee_icons(center: Vector2, icons: Array) -> void:
    if icons.is_empty():
        return
    var icon_size := Vector2(28, 28)
    var spacing := 32.0
    var count := icons.size()
    var start_x := -spacing * (float(count) - 1.0) * 0.5
    for i in icons.size():
        var tex: Texture2D = icons[i]
        if tex == null:
            continue
        var offset_x := start_x + spacing * float(i)
        var pos := center + Vector2(offset_x, -icon_size.y * 0.25) - icon_size * 0.5
        draw_texture_rect(tex, Rect2(pos, icon_size), false)

func _get_cell_center(coord: Vector2i) -> Vector2:
    return _positions.get(coord, Vector2.ZERO) + _grid_offset

func _draw() -> void:
    for coord in _hex_coords:
        var center: Vector2 = _positions.get(coord, Vector2.ZERO) + _grid_offset
        var points: PackedVector2Array = _hex_points(center)
        var cell_id: int = _cell_ids_by_coord.get(coord, -1)
        var cell_type := HiveSystem.get_cell_type(cell_id) if cell_id != -1 else "Empty"
        var fill_color: Color = _cell_type_colors.get(cell_type, hex_color)
        draw_colored_polygon(points, fill_color)
        if cell_id != -1:
            var icons := HiveSystem.get_cell_bee_icons(cell_id)
            _draw_bee_icons(center, icons)
        if coord == _selection:
            var outline_points: PackedVector2Array = points.duplicate()
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

func _on_cell_built(_cell_id: int, _cell_type: StringName) -> void:
    queue_redraw()

func _on_assignment_changed(_cell_id: int, _bee_id: int) -> void:
    queue_redraw()

func _on_production_tick(cell_id: int, resource_id: StringName, amount: int) -> void:
    if amount <= 0:
        return
    if not _coords_by_id.has(cell_id):
        return
    var coord: Vector2i = _coords_by_id[cell_id]
    var center: Vector2 = _get_cell_center(coord)
    var short_name: String = ConfigDB.get_resource_short_name(resource_id)
    _spawn_floating_text(center, "+%d %s" % [amount, short_name])

func _on_harvest_tick(_id: StringName, _time_left: float, partials: Dictionary) -> void:
    if typeof(partials) != TYPE_DICTIONARY or partials.is_empty():
        return
    var position: Vector2 = _find_gathering_hut_position()
    for key in partials.keys():
        var amount: int = int(partials.get(key, 0))
        if amount <= 0:
            continue
        var resource_id: StringName = StringName(String(key))
        var short_name: String = ConfigDB.get_resource_short_name(resource_id)
        _spawn_floating_text(position, "+%d %s" % [amount, short_name])

func _on_cell_converted(_cell_id: int, _new_type: StringName) -> void:
    queue_redraw()

func _spawn_floating_text(position: Vector2, text: String) -> void:
    var ft: Node = FloatingTextScene.instantiate()
    if ft == null:
        return
    if ft is Label:
        var label_ft: Label = ft
        add_child(label_ft)
        label_ft.global_position = position
        if label_ft.has_method("setup"):
            label_ft.setup(text)
        else:
            label_ft.text = text
    else:
        add_child(ft)
        ft.global_position = position
        if ft.has_method("setup"):
            ft.setup(text)

func _find_gathering_hut_position() -> Vector2:
    var cells: Dictionary = HiveSystem.get_cells()
    for cell_id in cells.keys():
        var entry: Dictionary = cells[cell_id]
        if String(entry.get("type", "")) != "GatheringHut":
            continue
        var id_int: int = int(cell_id)
        if _coords_by_id.has(id_int):
            var coord: Vector2i = _coords_by_id[id_int]
            return _get_cell_center(coord)
    return get_viewport_rect().size * 0.5
