extends Node
class_name BuildManager

@export var build_config: BuildConfig

signal build_started(cell_id: int)
signal build_finished(cell_id: int)
signal build_failed(cell_id: int)

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")
const MergeSystem := preload("res://scripts/systems/MergeSystem.gd")
const WorkerTasks := preload("res://scripts/systems/WorkerTasks.gd")

const BUILD_STATE_LOCKED := 0
const BUILD_STATE_AVAILABLE := 1
const BUILD_STATE_BUILT := 3

var _active_builds: Dictionary = {}

func request_build(cell_id: int, cell_type: StringName) -> bool:
    if build_config == null:
        push_warning("BuildConfig not assigned; cannot start build")
        emit_signal("build_failed", cell_id)
        return false
    if String(cell_type).is_empty():
        push_warning("Invalid cell type requested for build")
        emit_signal("build_failed", cell_id)
        return false
    if _active_builds.has(cell_id):
        return false
    var current_type: String = HiveSystem.get_cell_type(cell_id)
    if current_type != String(HiveSystem.EMPTY_TYPE) and current_type != "Empty":
        UIFx.flash_deny()
        emit_signal("build_failed", cell_id)
        return false
    var state: int = GameState.get_hive_cell_state(cell_id, BUILD_STATE_LOCKED)
    var is_new_build: bool = state == BUILD_STATE_AVAILABLE
    var is_existing_empty: bool = state == BUILD_STATE_BUILT and current_type == String(HiveSystem.EMPTY_TYPE)
    if not is_new_build and not is_existing_empty:
        UIFx.flash_deny()
        emit_signal("build_failed", cell_id)
        return false
    var base_cost: Dictionary = {}
    if is_new_build:
        base_cost = build_config.get_cost_dictionary()
    var specialization_cost: Dictionary = ConfigDB.get_cell_cost(cell_type)
    var total_cost: Dictionary = _combine_costs(base_cost, specialization_cost)
    var is_brood: bool = cell_type == StringName("Brood")
    if is_brood and ConfigDB.get_cell_requires_bee(cell_type):
        if not WorkerTasks.has_available_bee():
            _notify_insufficient_bees(cell_id)
            return false
    if not total_cost.is_empty():
        if not GameState.can_spend(total_cost):
            _notify_insufficient_resources(cell_id)
            return false
        if not GameState.spend(total_cost):
            _notify_insufficient_resources(cell_id)
            return false
    if is_existing_empty:
        _complete_build(cell_id, cell_type)
        Events.cell_built.emit(cell_id, cell_type)
        return true
    if is_brood:
        var build_seconds: float = ConfigDB.get_cell_build_seconds(cell_type)
        var reservation: Dictionary = GameState.reserve_bee_for_task()
        if reservation.is_empty():
            for key in total_cost.keys():
                var resource_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
                GameState.adjust_resource_quantity(resource_id, int(total_cost[key]))
            _notify_insufficient_bees(cell_id)
            return false
        var bee_id: int = int(reservation.get("id", -1))
        if bee_id <= 0:
            GameState.release_bee_from_task(bee_id)
            for key in total_cost.keys():
                var resource_id_fail: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
                GameState.adjust_resource_quantity(resource_id_fail, int(total_cost[key]))
            _notify_insufficient_bees(cell_id)
            return false
        var on_done := func() -> void:
            _active_builds.erase(cell_id)
            _complete_build(cell_id, cell_type)
            emit_signal("build_finished", cell_id)
            Events.cell_built.emit(cell_id, cell_type)
            Events.brood_built.emit(cell_id)
        var success_task: bool = WorkerTasks.run_build_or_repair(cell_id, build_seconds, bee_id, false, on_done)
        if not success_task:
            GameState.release_bee_from_task(bee_id)
            for key in total_cost.keys():
                var resource_id_retry: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
                GameState.adjust_resource_quantity(resource_id_retry, int(total_cost[key]))
            _notify_insufficient_bees(cell_id)
            return false
        var timer: SceneTreeTimer = WorkerTasks.get_task_timer(cell_id)
        var tracked_duration: float = build_seconds
        if timer != null:
            tracked_duration = max(timer.wait_time, 0.0)
        _active_builds[cell_id] = {"timer": timer, "cell_type": cell_type, "duration": tracked_duration}
        emit_signal("build_started", cell_id)
        return true
    var duration: float = max(build_config.build_time_sec, 0.0)
    if duration <= 0.0:
        emit_signal("build_started", cell_id)
        _complete_build(cell_id, cell_type)
        emit_signal("build_finished", cell_id)
        Events.cell_built.emit(cell_id, cell_type)
        return true
    var timer: SceneTreeTimer = get_tree().create_timer(duration)
    if timer == null:
        push_warning("Failed to create build timer")
        emit_signal("build_failed", cell_id)
        return false
    _active_builds[cell_id] = {
        "timer": timer,
        "cell_type": cell_type
    }
    timer.timeout.connect(func() -> void:
        _active_builds.erase(cell_id)
        _complete_build(cell_id, cell_type)
        emit_signal("build_finished", cell_id)
        Events.cell_built.emit(cell_id, cell_type)
    , CONNECT_ONE_SHOT)
    emit_signal("build_started", cell_id)
    return true

func is_building(cell_id: int) -> bool:
    return _active_builds.has(cell_id)

func get_progress(cell_id: int) -> float:
    if not _active_builds.has(cell_id):
        return 0.0
    var data: Variant = _active_builds.get(cell_id)
    if typeof(data) != TYPE_DICTIONARY:
        return 0.0
    var timer: SceneTreeTimer = data.get("timer", null)
    if timer == null:
        return 0.0
    var total: float = max(build_config.build_time_sec, 0.0001)
    var duration_value: Variant = data.get("duration", total)
    if typeof(duration_value) == TYPE_FLOAT or typeof(duration_value) == TYPE_INT:
        total = max(float(duration_value), 0.0001)
    var remaining: float = max(timer.time_left, 0.0)
    return clamp(1.0 - remaining / total, 0.0, 1.0)

func _complete_build(cell_id: int, cell_type: StringName) -> void:
    HiveSystem.convert_cell_type(cell_id, cell_type)
    MergeSystem.recompute_for(cell_id)

func _combine_costs(a: Dictionary, b: Dictionary) -> Dictionary:
    var combined: Dictionary = {}
    for key in a.keys():
        var resource: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
        var amount: float = float(a[key])
        combined[resource] = float(combined.get(resource, 0.0)) + amount
    for key in b.keys():
        var resource_b: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
        var amount_b: float = float(b[key])
        combined[resource_b] = float(combined.get(resource_b, 0.0)) + amount_b
    for key in combined.keys():
        combined[key] = int(round(float(combined[key])))
    return combined

func _notify_insufficient_resources(cell_id: int) -> void:
    UIFx.flash_deny()
    UIFx.show_toast("Not enough resources")
    emit_signal("build_failed", cell_id)

func _notify_insufficient_bees(cell_id: int) -> void:
    UIFx.flash_deny()
    UIFx.show_toast("No free bees available")
    emit_signal("build_failed", cell_id)
