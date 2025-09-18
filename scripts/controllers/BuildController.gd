extends Node
class_name BuildController

@export var build_menu_path: NodePath

var build_menu: BuildRadialMenu
var current_cell_id: int = -1

func _ready() -> void:
    if build_menu_path != NodePath():
        build_menu = get_node_or_null(build_menu_path)
    if build_menu:
        build_menu.menu_closed.connect(_on_menu_closed)
        build_menu.build_chosen.connect(_on_build_chosen)

func is_menu_open() -> bool:
    return build_menu != null and build_menu.is_open()

func open_radial(cell_id: int, world_position: Vector2) -> void:
    current_cell_id = cell_id
    if build_menu:
        build_menu.open_for_cell(cell_id, world_position)

func close_menu() -> void:
    if build_menu and build_menu.is_open():
        build_menu.close()

func _on_menu_closed() -> void:
    current_cell_id = -1

func _on_build_chosen(cell_type: StringName) -> void:
    # Placeholder hook for future build effects.
    pass
