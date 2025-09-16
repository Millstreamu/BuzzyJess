extends Node
class_name BuildController

static var tile_map: TileMap
static var built: Dictionary = {}

static func is_cell_buildable(cell: Vector2i) -> bool:
    return !built.has(cell)

static func attempt_build(cell: Vector2i, type: StringName) -> bool:
    if !is_cell_buildable(cell):
        return false
    built[cell] = type
    if tile_map:
        tile_map.set_cell(0, cell, 0, Vector2i.ZERO)
    return true
