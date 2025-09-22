extends Node
class_name BuildManager

@export var build_config: BuildConfig

signal build_started(cell_id: int)
signal build_finished(cell_id: int)
signal build_failed(cell_id: int)

var _active_builds: Dictionary = {}

func request_build(cell_id: int) -> bool:
    if build_config == null:
        push_warning("BuildConfig not assigned; cannot start build")
        return false
    if _active_builds.has(cell_id):
        return false
    var cost: Dictionary = build_config.get_cost_dictionary()
    if not cost.is_empty():
        if not GameState.can_spend(cost):
            _notify_insufficient_resources(cell_id)
            return false
        if not GameState.spend(cost):
            _notify_insufficient_resources(cell_id)
            return false
    var duration: float = max(build_config.build_time_sec, 0.0)
    if duration <= 0.0:
        emit_signal("build_started", cell_id)
        emit_signal("build_finished", cell_id)
        Events.cell_built.emit(cell_id, StringName("Empty"))
        return true
    var timer: SceneTreeTimer = get_tree().create_timer(duration)
    if timer == null:
        push_warning("Failed to create build timer")
        emit_signal("build_failed", cell_id)
        return false
    _active_builds[cell_id] = timer
    timer.timeout.connect(func() -> void:
        _active_builds.erase(cell_id)
        emit_signal("build_finished", cell_id)
        Events.cell_built.emit(cell_id, StringName("Empty"))
    , CONNECT_ONE_SHOT)
    emit_signal("build_started", cell_id)
    return true

func is_building(cell_id: int) -> bool:
    return _active_builds.has(cell_id)

func get_progress(cell_id: int) -> float:
    if not _active_builds.has(cell_id):
        return 0.0
    var timer: SceneTreeTimer = _active_builds.get(cell_id)
    if timer == null:
        return 0.0
    var total: float = max(build_config.build_time_sec, 0.0001)
    var remaining: float = max(timer.time_left, 0.0)
    return clamp(1.0 - remaining / total, 0.0, 1.0)

func _notify_insufficient_resources(cell_id: int) -> void:
    UIFx.flash_deny()
    UIFx.show_toast("Not enough resources")
    emit_signal("build_failed", cell_id)
