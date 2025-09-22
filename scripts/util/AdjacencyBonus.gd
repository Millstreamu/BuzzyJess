extends RefCounted
class_name AdjacencyBonus

const MergeSystem := preload("res://scripts/systems/MergeSystem.gd")

static func compute_effective_seconds(base_seconds: float, cell_type: StringName, cell_id: int) -> float:
    var effective_base := float(base_seconds)
    if cell_id < 0:
        return effective_base
    if not ConfigDB.get_cell_flag(cell_type, "adjacency_bonus_enabled"):
        return effective_base
    var per_neighbor: float = ConfigDB.get_cell_num(cell_type, "adjacency_time_bonus_per_neighbor_seconds", 0.0)
    var floor_seconds: float = ConfigDB.get_cell_num(cell_type, "adjacency_min_seconds", 0.0)
    var neighbors: int = MergeSystem.same_type_neighbor_count(cell_id)
    var adjusted: float = effective_base - per_neighbor * float(neighbors)
    return max(floor_seconds, adjusted)
