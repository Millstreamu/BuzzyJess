extends Node
class_name QueenController

@export var panel_path: NodePath

var panel: QueenFeedRadialMenu

func _ready() -> void:
    if panel_path != NodePath():
        panel = get_node_or_null(panel_path)
    if panel:
        panel.menu_closed.connect(_on_panel_closed)

func is_menu_open() -> bool:
    return panel != null and panel.is_open()

func open_panel(world_position: Vector2) -> void:
    if panel:
        panel.open_at(world_position)

func close_menu() -> void:
    if panel and panel.is_open():
        panel.close()

func _on_panel_closed() -> void:
    pass
