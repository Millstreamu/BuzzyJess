extends Node
class_name MergeSystem

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")

const NEIGHBOR_DIRS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1)
]

static func recompute_for(cell_id: int) -> void:
    var affected: Array[int] = _collect_affected_cells(cell_id)
    if affected.is_empty():
        return
    if typeof(Events) == TYPE_OBJECT and Events.has_signal("cell_neighbors_changed"):
        Events.cell_neighbors_changed.emit(affected)

static func same_type_neighbor_count(cell_id: int) -> int:
    if cell_id < 0:
        return 0
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        return 0
    var cell_type: String = String(entry.get("type", "Empty"))
    if cell_type == "Empty":
        return 0
    var coord: Vector2i = HiveSystem.get_cell_coord(cell_id)
    var count := 0
    for offset in NEIGHBOR_DIRS:
        var neighbor_coord: Vector2i = coord + offset
        var neighbor_id: int = HiveSystem.get_cell_id_at_coord(neighbor_coord)
        if neighbor_id == -1 or neighbor_id == cell_id:
            continue
        var neighbor_type: String = HiveSystem.get_cell_type(neighbor_id)
        if neighbor_type == cell_type:
            count += 1
    return count

static func neighbor_ids(cell_id: int) -> Array[int]:
    var result: Array[int] = Array[int]()
    if cell_id < 0:
        return result
    if HiveSystem.get_cell_entry(cell_id).is_empty():
        return result
    var coord: Vector2i = HiveSystem.get_cell_coord(cell_id)
    for offset in NEIGHBOR_DIRS:
        var neighbor_coord: Vector2i = coord + offset
        var neighbor_id: int = HiveSystem.get_cell_id_at_coord(neighbor_coord)
        if neighbor_id != -1:
            result.append(neighbor_id)
    return result

static func _collect_affected_cells(cell_id: int) -> Array[int]:
    var unique: Dictionary = {}
    if cell_id != -1:
        unique[cell_id] = true
        for neighbor_id in neighbor_ids(cell_id):
            unique[neighbor_id] = true
    var keys: Array = unique.keys()
    var result: Array[int] = Array[int]()
    for key in keys:
        result.append(int(key))
    return result
