extends Node
class_name HiveSystem

static var _cells: Dictionary = {}

static func reset() -> void:
    _cells.clear()

static func register_cell(cell_id: int, data: Dictionary) -> void:
    _cells[cell_id] = data.duplicate(true)

static func convert_cell_type(cell_id: int, new_type: StringName) -> void:
    if not _cells.has(cell_id):
        return
    _cells[cell_id]["type"] = String(new_type)

static func get_cell_type(cell_id: int) -> String:
    return _cells.get(cell_id, {}).get("type", "Empty")

static func get_cells() -> Dictionary:
    return _cells.duplicate(true)
