# -----------------------------------------------------------------------------
# File: scripts/HexGridTest.gd
# Purpose: Debug/test scene for interacting with the hive grid
# Depends: InputActions, BuildManager, various UI controllers
# Notes: Provides keyboard shortcuts for toggling UI panels during testing
# -----------------------------------------------------------------------------

## HexGridTest
## Drives the sandbox scene used for development testing of hive features.
extends Node2D

const _HiveSystemScript := preload("res://scripts/systems/HiveSystem.gd")
const _MergeSystemScript := preload("res://scripts/systems/MergeSystem.gd")
const FloatingTextScene := preload("res://scenes/FX/FloatingText.tscn")
const HAMMER_TEXTURE := preload("res://art/icons/hammer.svg")
const QueenSelectScene := preload("res://scenes/UI/QueenSelect.tscn")
const SEAT_TYPE := StringName("QueenSeat")

@export var hex_size: float = 48.0
@export var hex_color: Color = Color(1.0, 0.9, 0.1)
@export var selection_color: Color = Color(1.0, 0.6, 0.0)
@export var selection_line_width: float = 4.0

var _hex_coords: Array[Vector2i] = []
var _positions: Dictionary = {}
var _cell_ids_by_coord: Dictionary = {}
var _coords_by_id: Dictionary = {}
var _selection: Vector2i = Vector2i.ZERO
var _grid_offset: Vector2 = Vector2.ZERO
var _next_cell_id: int = 0
var _queen_cell_id: int = -1
var _queen_select_active: bool = false
var _queen_select_prev_paused: bool = false

const SQRT_3 := sqrt(3.0)

enum BuildState { LOCKED, AVAILABLE, BUILDING, BUILT }

const NEIGHBOR_DIRS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1)
]

var _cell_type_colors: Dictionary = {
    "Empty": Color(1.0, 0.9, 0.1),
    "QueenSeat": Color(1.0, 0.85, 0.45),
    "Brood": Color(0.8, 0.4, 0.4),
    "Storage": Color(0.7, 0.7, 0.2),
    "HoneyVat": Color(0.9, 0.7, 0.3),
    "WaxWorkshop": Color(0.7, 0.5, 0.3),
    "CandleHall": Color(0.6, 0.5, 0.9),
    "GuardPost": Color(0.4, 0.6, 0.8),
    "GatheringHut": Color(0.5, 0.8, 0.5),
    "Damaged": Color(0.25, 0.23, 0.28)
}

var _cell_states: Dictionary = {}
var _building_progress: Dictionary = {}
var _hover_cell_id: int = -1
var _abilities_unlocked: bool = false

@onready var _build_controller: BuildController = $BuildController
@onready var _assign_controller: AssignController = $AssignController
@onready var _gathering_controller: GatheringController = $GatheringController
@onready var _build_menu: BuildRadialMenu = $CanvasLayer/BuildRadialMenu
@onready var _resources_panel: ResourcesPanel = $CanvasLayer/ResourcesPanel
@onready var _inventory_panel: InventoryPanel = $CanvasLayer/InventoryPanel
@onready var _abilities_panel: AbilitiesPanel = $CanvasLayer/AbilitiesPanel
@onready var _build_manager: BuildManager = $BuildManager
@onready var _queen_controller: QueenController = $QueenController
@onready var _brood_controller: BroodController = $BroodController
@onready var _candle_radial: RadialCandleHall = $CanvasLayer/RadialCandleHall

func _ready() -> void:
    _generate_grid()
    if _build_manager:
        if not _build_manager.build_started.is_connected(_on_cell_build_started):
            _build_manager.build_started.connect(_on_cell_build_started)
        if not _build_manager.build_finished.is_connected(_on_cell_build_finished):
            _build_manager.build_finished.connect(_on_cell_build_finished)
    if not Events.cell_built.is_connected(_on_cell_built):
        Events.cell_built.connect(_on_cell_built)
    if not Events.task_started.is_connected(_on_task_started):
        Events.task_started.connect(_on_task_started)
    if not Events.task_finished.is_connected(_on_task_finished):
        Events.task_finished.connect(_on_task_finished)
    if not Events.cell_repaired.is_connected(_on_cell_repaired):
        Events.cell_repaired.connect(_on_cell_repaired)
    if not Events.assignment_changed.is_connected(_on_assignment_changed):
        Events.assignment_changed.connect(_on_assignment_changed)
    if not Events.production_tick.is_connected(_on_production_tick):
        Events.production_tick.connect(_on_production_tick)
    if not Events.cell_converted.is_connected(_on_cell_converted):
        Events.cell_converted.connect(_on_cell_converted)
    if Events.has_signal("cell_neighbors_changed") and not Events.cell_neighbors_changed.is_connected(_on_cell_neighbors_changed):
        Events.cell_neighbors_changed.connect(_on_cell_neighbors_changed)
    if not Events.harvest_tick.is_connected(_on_harvest_tick):
        Events.harvest_tick.connect(_on_harvest_tick)
    if not Events.queen_fed.is_connected(_on_queen_fed):
        Events.queen_fed.connect(_on_queen_fed)
    if not Events.bee_hatched.is_connected(_on_bee_hatched):
        Events.bee_hatched.connect(_on_bee_hatched)
    if not Events.abilities_unlocked.is_connected(_on_abilities_unlocked):
        Events.abilities_unlocked.connect(_on_abilities_unlocked)
    if typeof(CandleHallSystem) == TYPE_OBJECT and CandleHallSystem.unlocked():
        _abilities_unlocked = true
    queue_redraw()
    var viewport := get_viewport()
    if viewport:
        viewport.size_changed.connect(_on_viewport_size_changed)
    set_process(true)
    call_deferred("_show_queen_selection")

func _on_viewport_size_changed() -> void:
    _update_offset()
    queue_redraw()

func _generate_grid() -> void:
    _hex_coords.clear()
    _positions.clear()
    _cell_ids_by_coord.clear()
    _coords_by_id.clear()
    _cell_states.clear()
    _building_progress.clear()
    _next_cell_id = 0
    _queen_cell_id = -1
    HiveSystem.reset()
    GameState.hive_cell_states.clear()
    GameState.reset_queen_selection()

    var queen_coord := Vector2i.ZERO
    var queen_id := _ensure_cell_entry(queen_coord, "Empty")
    _queen_cell_id = queen_id
    HiveSystem.set_center_cell(queen_id)
    _set_cell_state(queen_id, BuildState.BUILT)
    _set_selection(queen_coord)
    _add_available_neighbors(queen_id)
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
    queue_redraw()

func _ensure_cell_entry(coord: Vector2i, cell_type: String = "Empty") -> int:
    if _cell_ids_by_coord.has(coord):
        return int(_cell_ids_by_coord[coord])
    var cell_id: int = _next_cell_id
    _next_cell_id += 1
    if not _hex_coords.has(coord):
        _hex_coords.append(coord)
    var pos := _axial_to_pixel(coord)
    _positions[coord] = pos
    _cell_ids_by_coord[coord] = cell_id
    _coords_by_id[cell_id] = coord
    HiveSystem.register_cell(cell_id, {
        "coord": coord,
        "type": cell_type
    })
    return cell_id

func _set_cell_state(cell_id: int, state: int) -> void:
    _cell_states[cell_id] = state
    GameState.set_hive_cell_state(cell_id, int(state))

func _add_available_neighbors(cell_id: int) -> void:
    if not _coords_by_id.has(cell_id):
        return
    var coord: Vector2i = _coords_by_id[cell_id]
    var added_new: bool = false
    for offset in NEIGHBOR_DIRS:
        var neighbor_coord := coord + offset
        var was_new: bool = not _cell_ids_by_coord.has(neighbor_coord)
        var neighbor_id: int = _ensure_cell_entry(neighbor_coord)
        if neighbor_id == _queen_cell_id:
            continue
        var current_state: int = int(_cell_states.get(neighbor_id, BuildState.LOCKED))
        if was_new:
            _set_cell_state(neighbor_id, BuildState.AVAILABLE)
            added_new = true
        elif current_state == BuildState.LOCKED:
            _set_cell_state(neighbor_id, BuildState.AVAILABLE)
    if added_new:
        _update_offset()
    else:
        queue_redraw()

func _process(_delta: float) -> void:
    if _build_manager == null:
        return
    var has_building := false
    for cell_id in _cell_states.keys():
        if int(_cell_states[cell_id]) != BuildState.BUILDING:
            continue
        var progress: float = _build_manager.get_progress(cell_id)
        _building_progress[cell_id] = progress
        has_building = true
    if has_building:
        queue_redraw()
    else:
        _building_progress.clear()

func _unhandled_input(event: InputEvent) -> void:
    if _queen_select_active:
        return
    if event.is_action_pressed(InputActions.ABILITIES_PANEL_TOGGLE):
        _close_candle_radial()
        var viewport_abilities := get_viewport()
        var abilities_ready := _abilities_unlocked
        if not abilities_ready and typeof(CandleHallSystem) == TYPE_OBJECT:
            abilities_ready = CandleHallSystem.unlocked()
        if abilities_ready and _abilities_panel:
            _abilities_panel.toggle()
        else:
            UIFx.flash_deny()
        if viewport_abilities:
            viewport_abilities.set_input_as_handled()
        return
    if event.is_action_pressed(InputActions.GATHER_PANEL_TOGGLE):
        _close_candle_radial()
        if _gathering_controller:
            _gathering_controller.toggle_panel()
        var viewport_toggle := get_viewport()
        if viewport_toggle:
            viewport_toggle.set_input_as_handled()
        return

    if event.is_action_pressed(InputActions.RESOURCES_PANEL_TOGGLE):
        _close_candle_radial()
        if _resources_panel:
            _resources_panel.toggle()
        var viewport := get_viewport()
        if viewport:
            viewport.set_input_as_handled()
        return

    if event.is_action_pressed(InputActions.INVENTORY_PANEL_TOGGLE):
        _close_candle_radial()
        if _inventory_panel:
            _inventory_panel.toggle()
        var viewport_inventory := get_viewport()
        if viewport_inventory:
            viewport_inventory.set_input_as_handled()
        return

    if (_build_menu and _build_menu.is_open()) or (_queen_controller and _queen_controller.is_menu_open()) or (_brood_controller and _brood_controller.is_panel_open()) or (_assign_controller and _assign_controller.is_panel_open()) or (_resources_panel and _resources_panel.is_open()) or (_inventory_panel and _inventory_panel.is_open()) or (_gathering_controller and _gathering_controller.is_panel_open()) or (_abilities_panel and _abilities_panel.is_open()) or (_candle_radial and _candle_radial.is_open()):
        return

    if event.is_action_pressed(InputActions.UI_RIGHT):
        _try_move_selection(Vector2i(1, 0))
    elif event.is_action_pressed(InputActions.UI_LEFT):
        _try_move_selection(Vector2i(-1, 0))
    elif event.is_action_pressed(InputActions.UI_UP):
        _try_move_selection(Vector2i(0, -1))
    elif event.is_action_pressed(InputActions.UI_DOWN):
        _try_move_selection(Vector2i(0, 1))
    elif event.is_action_pressed(InputActions.CONFIRM):
        _handle_confirm()

func _try_move_selection(delta: Vector2i) -> void:
    var next_coord := _selection + delta
    if _positions.has(next_coord):
        _set_selection(next_coord)

func _set_selection(coord: Vector2i) -> void:
    _selection = coord
    _hover_cell_id = _cell_ids_by_coord.get(_selection, -1)
    queue_redraw()

func _handle_confirm() -> void:
    var cell_id: int = _cell_ids_by_coord.get(_selection, -1)
    if cell_id == -1:
        return
    _handle_cell_interaction(cell_id, _selection)

func _handle_cell_interaction(cell_id: int, coord: Vector2i) -> void:
    _close_candle_radial()
    if cell_id == _queen_cell_id:
        if GameState.queen_id == StringName(""):
            UIFx.flash_deny()
            return
        if _queen_controller:
            var queen_world_position: Vector2 = get_cell_center_world(cell_id)
            _queen_controller.open_panel(queen_world_position)
        else:
            UIFx.flash_deny()
        return
    var state: int = int(_cell_states.get(cell_id, BuildState.LOCKED))
    if state == BuildState.AVAILABLE:
        if _build_controller:
            var world_position_available: Vector2 = _get_cell_center(coord)
            _build_controller.open_radial(cell_id, world_position_available)
        else:
            UIFx.flash_deny()
        return
    if state == BuildState.BUILDING:
        return
    var cell_type := HiveSystem.get_cell_type(cell_id)
    if cell_type == "Empty":
        if _build_controller:
            var world_position: Vector2 = _get_cell_center(coord)
            _build_controller.open_radial(cell_id, world_position)
    else:
        var cell_type_name: StringName = StringName(cell_type)
        if cell_type_name == StringName("Brood"):
            if _brood_controller:
                var brood_world_position: Vector2 = get_cell_center_world(cell_id)
                _brood_controller.open_panel(cell_id, brood_world_position)
            else:
                UIFx.flash_deny()
            return
        if cell_type_name == StringName("CandleHall"):
            if _candle_radial:
                var hall_world_position: Vector2 = get_cell_center_world(cell_id)
                _candle_radial.open_for_cell(cell_id, hall_world_position)
            else:
                UIFx.flash_deny()
            return
        if not ConfigDB.is_cell_assignable(cell_type_name):
            UIFx.flash_deny()
            return
        if _assign_controller:
            _assign_controller.open_panel(cell_id)

func _close_candle_radial() -> void:
    if _candle_radial and _candle_radial.is_open():
        _candle_radial.close()

func _on_abilities_unlocked() -> void:
    if typeof(CandleHallSystem) == TYPE_OBJECT:
        _abilities_unlocked = CandleHallSystem.unlocked()
    else:
        _abilities_unlocked = true

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

func get_cell_center_world(cell_id: int) -> Vector2:
    if not _coords_by_id.has(cell_id):
        return to_global(Vector2.ZERO)
    var coord: Vector2i = _coords_by_id[cell_id]
    var local_center: Vector2 = _get_cell_center(coord)
    return to_global(local_center)

func _draw() -> void:
    for coord in _hex_coords:
        var center: Vector2 = _get_cell_center(coord)
        var points: PackedVector2Array = _hex_points(center)
        var cell_id: int = _cell_ids_by_coord.get(coord, -1)
        var cell_type := HiveSystem.get_cell_type(cell_id) if cell_id != -1 else "Empty"
        var fill_color: Color = _cell_type_colors.get(cell_type, hex_color)
        var state: int = BuildState.LOCKED
        if cell_id != -1:
            state = int(_cell_states.get(cell_id, BuildState.LOCKED))
        match state:
            BuildState.LOCKED:
                fill_color = fill_color.darkened(0.45)
                fill_color.a = 0.65
            BuildState.AVAILABLE:
                fill_color.a = 0.5
            BuildState.BUILDING:
                fill_color = fill_color.lerp(Color.WHITE, 0.1)
                fill_color.a = max(fill_color.a, 0.85)
            BuildState.BUILT:
                fill_color.a = 1.0
        if cell_id == _hover_cell_id and state != BuildState.LOCKED:
            fill_color = fill_color.lerp(Color.WHITE, 0.2)
            if state == BuildState.AVAILABLE:
                fill_color.a = 0.5
        draw_colored_polygon(points, fill_color)
        if cell_id != -1 and state == BuildState.BUILT:
            var neighbor_count: int = MergeSystem.same_type_neighbor_count(cell_id)
            if neighbor_count > 0:
                var outline_color: Color = _cell_type_colors.get(cell_type, hex_color).darkened(0.3)
                var outline_points: PackedVector2Array = _hex_points(center, hex_size * 0.82)
                outline_points.append(outline_points[0])
                draw_polyline(outline_points, outline_color, max(hex_size * 0.08, 3.0))
        if cell_id != -1:
            if state == BuildState.AVAILABLE and HAMMER_TEXTURE:
                var hammer_scale := hex_size * 1.1
                var rect := Rect2(center - Vector2(hammer_scale, hammer_scale) * 0.5, Vector2.ONE * hammer_scale)
                draw_texture_rect(HAMMER_TEXTURE, rect, false)
            elif state == BuildState.BUILDING:
                var progress: float = clamp(float(_building_progress.get(cell_id, _build_manager.get_progress(cell_id) if _build_manager else 0.0)), 0.0, 1.0)
                var ring_radius := hex_size * 0.95
                var ring_width: float = max(hex_size * 0.12, 3.0)
                var background_color := selection_color.darkened(0.5)
                draw_arc(center, ring_radius, -PI / 2.0, -PI / 2.0 + TAU, 64, background_color, ring_width * 0.4)
                draw_arc(center, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, selection_color, ring_width)
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

func _hex_points(center: Vector2, radius: float = hex_size) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := PI / 6.0 + PI / 3.0 * float(i)
        var point := center + Vector2(cos(angle), sin(angle)) * radius
        points.append(point)
    return points

func _on_cell_build_started(cell_id: int) -> void:
    _set_cell_state(cell_id, BuildState.BUILDING)
    _building_progress[cell_id] = 0.0
    queue_redraw()

func _on_cell_build_finished(cell_id: int) -> void:
    _set_cell_state(cell_id, BuildState.BUILT)
    _building_progress.erase(cell_id)
    _add_available_neighbors(cell_id)

func _on_task_started(cell_id: int, kind: StringName, _bee_id: int, _ends_at: float) -> void:
    if kind != StringName("build") and kind != StringName("repair"):
        return
    _set_cell_state(cell_id, BuildState.BUILDING)
    _building_progress[cell_id] = 0.0
    queue_redraw()

func _on_task_finished(cell_id: int, kind: StringName, _bee_id: int, success: bool) -> void:
    if kind != StringName("build") and kind != StringName("repair"):
        return
    _building_progress.erase(cell_id)
    if success:
        _set_cell_state(cell_id, BuildState.BUILT)
        _add_available_neighbors(cell_id)
    else:
        _set_cell_state(cell_id, BuildState.AVAILABLE)
    queue_redraw()

func _on_cell_built(_cell_id: int) -> void:
    queue_redraw()

func _on_cell_repaired(_cell_id: int) -> void:
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
    var hut_position: Vector2 = _find_gathering_hut_position()
    for key in partials.keys():
        var amount: int = int(partials.get(key, 0))
        if amount <= 0:
            continue
        var resource_id: StringName = StringName(String(key))
        var short_name: String = ConfigDB.get_resource_short_name(resource_id)
        _spawn_floating_text(hut_position, "+%d %s" % [amount, short_name])

func _on_queen_fed(tier: StringName) -> void:
    if _queen_cell_id == -1:
        return
    if not _coords_by_id.has(_queen_cell_id):
        return
    var coord: Vector2i = _coords_by_id[_queen_cell_id]
    var center: Vector2 = _get_cell_center(coord)
    var tier_string: String = String(tier)
    _spawn_floating_text(center, "+1 Egg (%s)" % tier_string)

func _on_bee_hatched(cell_id: int, _bee_id: int, rarity: StringName) -> void:
    if not _coords_by_id.has(cell_id):
        return
    var coord: Vector2i = _coords_by_id[cell_id]
    var center: Vector2 = _get_cell_center(coord)
    _spawn_floating_text(center, "+1 %s Bee" % String(rarity))

func _on_cell_converted(cell_id: int, _new_type: StringName) -> void:
    MergeSystem.recompute_for(cell_id)
    queue_redraw()

func _on_cell_neighbors_changed(_cell_ids: Array) -> void:
    queue_redraw()

func _show_queen_selection() -> void:
    if GameState.queen_id != StringName(""):
        _queen_select_active = false
        _ensure_queen_tile_state()
        return
    if QueenSelectScene == null:
        return
    var overlay: Node = QueenSelectScene.instantiate()
    if overlay == null:
        return
    overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    if overlay.has_signal("queen_confirmed"):
        overlay.connect("queen_confirmed", Callable(self, "_on_queen_confirmed"))
    if overlay.has_signal("selection_closed"):
        overlay.connect("selection_closed", Callable(self, "_on_queen_selection_closed"))
    var parent_node: Node = $CanvasLayer if has_node("CanvasLayer") else self
    parent_node.add_child(overlay)
    _queen_select_active = true
    var tree := get_tree()
    if tree:
        _queen_select_prev_paused = tree.paused
        tree.paused = true

func _on_queen_confirmed(_queen_id: StringName) -> void:
    _queen_select_active = false
    _ensure_queen_tile_state()
    queue_redraw()

func _on_queen_selection_closed() -> void:
    var tree := get_tree()
    if tree:
        tree.paused = _queen_select_prev_paused
    _queen_select_active = false
    queue_redraw()

func _ensure_queen_tile_state() -> void:
    if _queen_cell_id == -1:
        return
    if GameState.queen_id == StringName(""):
        return
    if HiveSystem.get_cell_type(_queen_cell_id) == String(SEAT_TYPE):
        return
    HiveSystem.set_cell_type(_queen_cell_id, SEAT_TYPE)

func _spawn_floating_text(world_position: Vector2, text: String) -> void:
    var ft: Node = FloatingTextScene.instantiate()
    if ft == null:
        return
    if ft is Label:
        var label_ft: Label = ft
        add_child(label_ft)
        label_ft.global_position = world_position
        if label_ft.has_method("setup"):
            label_ft.setup(text)
        else:
            label_ft.text = text
    else:
        add_child(ft)
        ft.global_position = world_position
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
