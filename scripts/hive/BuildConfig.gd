extends Resource
class_name BuildConfig

@export var cost_honey: int = 5
@export var cost_comb: int = 1
@export var requires_free_bee: bool = false
@export var build_time_sec: float = 3.0
@export var sfx_click: AudioStream
@export var sfx_build_complete: AudioStream

func get_cost_dictionary() -> Dictionary:
    var cost: Dictionary = {}
    if cost_honey > 0:
        cost["Honey"] = cost_honey
    if cost_comb > 0:
        cost["Comb"] = cost_comb
    return cost
