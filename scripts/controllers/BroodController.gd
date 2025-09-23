extends Node
class_name BroodController

@export var panel_path: NodePath

var panel: BroodInsertRadialMenu = null
var _current_cell: int = -1

func _ready() -> void:
    if panel_path != NodePath():
        panel = get_node_or_null(panel_path)
    if panel:
        panel.menu_closed.connect(_on_panel_closed)

func open_panel(cell_id: int, world_position: Vector2) -> void:
    if panel == null:
        return
    var meta: Dictionary = HiveSystem.get_cell_metadata(cell_id)
    if meta.has("hatch"):
        UIFx.flash_deny()
        return
    _current_cell = cell_id
    panel.open_for_cell(cell_id, world_position)

func close_panel() -> void:
    if panel and panel.is_open():
        panel.close()

func is_panel_open() -> bool:
    return panel != null and panel.is_open()

func _on_panel_closed() -> void:
    _current_cell = -1
