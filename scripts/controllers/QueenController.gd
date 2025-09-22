extends Node
class_name QueenController

@export var feed_menu_path: NodePath

var feed_menu: QueenFeedRadialMenu

func _ready() -> void:
    if feed_menu_path != NodePath():
        feed_menu = get_node_or_null(feed_menu_path)
    if feed_menu:
        feed_menu.menu_closed.connect(_on_menu_closed)
        feed_menu.feed_executed.connect(_on_feed_executed)

func is_menu_open() -> bool:
    return feed_menu != null and feed_menu.is_open()

func open_radial(world_position: Vector2) -> void:
    if feed_menu:
        feed_menu.open_at(world_position)

func close_menu() -> void:
    if feed_menu and feed_menu.is_open():
        feed_menu.close()

func _on_menu_closed() -> void:
    pass

func _on_feed_executed(_honey_amount: int, _eggs: int) -> void:
    pass
