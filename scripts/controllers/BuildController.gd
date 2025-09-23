extends Node
class_name BuildController

@export var build_menu_path: NodePath
@export var build_manager_path: NodePath

const BUILD_STATE_LOCKED := 0
const BUILD_STATE_AVAILABLE := 1

const WorkerTasks := preload("res://scripts/systems/WorkerTasks.gd")

var build_menu: BuildRadialMenu
var build_manager: BuildManager
var current_cell_id: int = -1

func _ready() -> void:
    if build_menu_path != NodePath():
        build_menu = get_node_or_null(build_menu_path)
    if build_manager_path != NodePath():
        build_manager = get_node_or_null(build_manager_path)
    if build_menu:
        build_menu.menu_closed.connect(_on_menu_closed)
        build_menu.build_chosen.connect(_on_build_chosen)

func is_menu_open() -> bool:
    return build_menu != null and build_menu.is_open()

func open_radial(cell_id: int, world_position: Vector2) -> void:
    current_cell_id = cell_id
    var state: int = GameState.get_hive_cell_state(cell_id, BUILD_STATE_LOCKED)
    if state == BUILD_STATE_AVAILABLE:
        var started: bool = WorkerTasks.start_build(cell_id)
        if not started:
            UIFx.flash_deny()
        current_cell_id = -1
        return
    if build_menu:
        var include_base_cost: bool = state == BUILD_STATE_AVAILABLE
        var base_cost: Dictionary = {}
        if include_base_cost:
            base_cost = _get_base_build_cost()
        build_menu.set_base_cost(base_cost)
        build_menu.open_for_cell(cell_id, world_position)

func close_menu() -> void:
    if build_menu and build_menu.is_open():
        build_menu.close()

func _on_menu_closed() -> void:
    current_cell_id = -1
    if build_menu:
        build_menu.set_base_cost({})

func _on_build_chosen(cell_type: StringName, option_index: int) -> void:
    if current_cell_id == -1:
        return
    if build_manager == null:
        push_warning("BuildManager not assigned; cannot start build")
        if build_menu:
            build_menu.show_unaffordable_feedback(option_index)
        return
    var success: bool = build_manager.request_build(current_cell_id, cell_type)
    if success:
        build_menu.close()
    elif build_menu:
        build_menu.show_unaffordable_feedback(option_index)

func _get_base_build_cost() -> Dictionary:
    if build_manager and build_manager.build_config:
        return build_manager.build_config.get_cost_dictionary()
    return {}
