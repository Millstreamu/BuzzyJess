extends Node2D

@onready var hex_map: TileMap = $HexMap
@onready var cursor: Node2D = $Cursor
var selected_cell: Vector2i = Vector2i(0, 0)

func _ready() -> void:
    _populate_demo_grid(12, 10) # q in [0..11], r in [0..9]
    _update_cursor_position()

func _populate_demo_grid(w:int, h:int) -> void:
    # Assumes your TileSet has a source_id = 0 and tile_id = 0 for the yellow hex.
    for q in w:
        for r in h:
            hex_map.set_cell(0, Vector2i(q, r), 0, Vector2i.ZERO)  # layer=0, source_id=0

func _unhandled_input(event: InputEvent) -> void:
    var delta := Vector2i.ZERO
    if event.is_action_pressed("ui_right"):
        delta = Vector2i(1, 0)
    elif event.is_action_pressed("ui_left"):
        delta = Vector2i(-1, 0)
    elif event.is_action_pressed("ui_down"):
        delta = Vector2i(0, 1)
    elif event.is_action_pressed("ui_up"):
        delta = Vector2i(0, -1)
    if delta != Vector2i.ZERO:
        _try_move_selection(delta)

func _try_move_selection(delta: Vector2i) -> void:
    var next := selected_cell + delta
    # Check if a tile exists at next
    if hex_map.get_cell_source_id(0, next) != -1:
        selected_cell = next
        _update_cursor_position()

func _update_cursor_position() -> void:
    # Center the Cursor on the target cell
    var local_pos := hex_map.map_to_local(selected_cell)
    # For hex TileMap, map_to_local returns the cell origin; center adjust by half tile
    var center_offset := Vector2(hex_map.tile_set.tile_size.x * 0.5, hex_map.tile_set.tile_size.y * 0.5)
    cursor.position = local_pos + center_offset
