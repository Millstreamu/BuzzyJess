extends Node
class_name WorkerTasks

const KIND_BUILD := StringName("build")
const KIND_REPAIR := StringName("repair")

const BUILD_STATE_LOCKED := 0
const BUILD_STATE_AVAILABLE := 1
const BUILD_STATE_BUILDING := 2
const BUILD_STATE_BUILT := 3

const TRAIT_CONSTRUCTION := StringName("Construction")

const TASK_PROGRESS_SCENE := preload("res://scenes/UI/TaskProgress.tscn")

const MergeSystem := preload("res://scripts/systems/MergeSystem.gd")

static var _tasks: Dictionary = {}

static func has_available_bee(preferred_trait: StringName = StringName("")) -> bool:
    return GameState.find_available_bee(preferred_trait) != -1

static func start_build(cell_id: int) -> bool:
    if _tasks.has(cell_id):
        return false
    var state: int = GameState.get_hive_cell_state(cell_id, BUILD_STATE_LOCKED)
    if state != BUILD_STATE_AVAILABLE:
        return false
    if not HiveSystem.is_adjacent_to_any(cell_id):
        return false
    var cfg: Dictionary = ConfigDB.get_cell_build_task(HiveSystem.EMPTY_TYPE)
    if cfg.is_empty():
        return false
    var cost: Dictionary = cfg.get("cost", {})
    if not cost.is_empty() and not GameState.can_spend(cost):
        return false
    var bee_id: int = GameState.get_free_bee_id()
    if bee_id == -1:
        return false
    if not GameState.reserve_bee(bee_id):
        return false
    if not cost.is_empty() and not GameState.spend(cost):
        GameState.release_bee(bee_id)
        return false
    var base_seconds: float = float(cfg.get("seconds", 0.0))
    var wait: float = _compute_wait_seconds(base_seconds, bee_id, float(cfg.get("trait_construction_bonus", 0.0)), false)
    GameState.set_hive_cell_state(cell_id, BUILD_STATE_BUILDING)
    var success := _schedule_task(cell_id, KIND_BUILD, bee_id, wait, func() -> void:
        HiveSystem.create_empty_cell(cell_id)
        GameState.set_hive_cell_state(cell_id, BUILD_STATE_BUILT)
        _unlock_neighbor_cells(cell_id)
        MergeSystem.recompute_for(cell_id)
        if typeof(Events) == TYPE_OBJECT:
            Events.cell_built.emit(cell_id)
    , {
        "ring": true,
        "emit_started": true,
        "emit_finished": true,
        "emit_resources_changed": true
    })
    if not success:
        GameState.set_hive_cell_state(cell_id, BUILD_STATE_AVAILABLE)
        GameState.release_bee(bee_id)
        if not cost.is_empty():
            for resource in cost.keys():
                var resource_id: StringName = resource if typeof(resource) == TYPE_STRING_NAME else StringName(String(resource))
                GameState.adjust_resource_quantity(resource_id, int(cost[resource]))
    return success

static func start_repair(cell_id: int) -> bool:
    if _tasks.has(cell_id):
        return false
    var cell_type: String = HiveSystem.get_cell_type(cell_id)
    if cell_type != String(HiveSystem.DAMAGED_TYPE):
        return false
    var cfg: Dictionary = ConfigDB.get_cell_repair_task(HiveSystem.DAMAGED_TYPE)
    if cfg.is_empty():
        return false
    var cost: Dictionary = cfg.get("cost", {})
    if not cost.is_empty() and not GameState.can_spend(cost):
        return false
    var bee_id: int = GameState.get_free_bee_id()
    if bee_id == -1:
        return false
    if not GameState.reserve_bee(bee_id):
        return false
    if not cost.is_empty() and not GameState.spend(cost):
        GameState.release_bee(bee_id)
        return false
    var base_seconds: float = float(cfg.get("seconds", 0.0))
    var wait: float = _compute_wait_seconds(base_seconds, bee_id, float(cfg.get("trait_construction_bonus", 0.0)), true)
    GameState.set_hive_cell_state(cell_id, BUILD_STATE_BUILDING)
    var success := _schedule_task(cell_id, KIND_REPAIR, bee_id, wait, func() -> void:
        HiveSystem.set_cell_type(cell_id, HiveSystem.EMPTY_TYPE)
        GameState.set_hive_cell_state(cell_id, BUILD_STATE_BUILT)
        _unlock_neighbor_cells(cell_id)
        MergeSystem.recompute_for(cell_id)
        if typeof(Events) == TYPE_OBJECT:
            Events.cell_repaired.emit(cell_id)
            Events.cell_built.emit(cell_id)
    , {
        "ring": true,
        "emit_started": true,
        "emit_finished": true,
        "emit_resources_changed": true
    })
    if not success:
        GameState.set_hive_cell_state(cell_id, BUILD_STATE_BUILT)
        GameState.release_bee(bee_id)
        if not cost.is_empty():
            for resource in cost.keys():
                var resource_id: StringName = resource if typeof(resource) == TYPE_STRING_NAME else StringName(String(resource))
                GameState.adjust_resource_quantity(resource_id, int(cost[resource]))
    return success

static func run_build_or_repair(cell_id: int, base_seconds: float, bee_id: int, is_repair: bool, on_done: Callable = Callable()) -> bool:
    if bee_id <= 0:
        return false
    var wait: float = max(1.0, base_seconds - (is_repair ? TraitsSystem.repair_time_bonus_seconds(bee_id) : TraitsSystem.build_time_bonus_seconds(bee_id)))
    return _schedule_task(cell_id, is_repair ? KIND_REPAIR : KIND_BUILD, bee_id, wait, on_done)

static func get_task_timer(cell_id: int) -> SceneTreeTimer:
    if not _tasks.has(cell_id):
        return null
    var data: Dictionary = _tasks[cell_id]
    return data.get("timer", null)

static func get_task_duration(cell_id: int) -> float:
    if not _tasks.has(cell_id):
        return 0.0
    var data: Dictionary = _tasks[cell_id]
    var duration_value: Variant = data.get("duration", 0.0)
    if typeof(duration_value) == TYPE_FLOAT or typeof(duration_value) == TYPE_INT:
        return max(float(duration_value), 0.0)
    return 0.0

static func _compute_wait_seconds(base_seconds: float, bee_id: int, cfg_bonus: float, is_repair: bool) -> float:
    var bonus: float = 0.0
    if cfg_bonus > 0.0 and TraitsSystem.bee_has(bee_id, TRAIT_CONSTRUCTION):
        bonus = cfg_bonus
    else:
        bonus = is_repair ? TraitsSystem.repair_time_bonus_seconds(bee_id) : TraitsSystem.build_time_bonus_seconds(bee_id)
        if cfg_bonus > 0.0 and bonus > 0.0:
            bonus = min(bonus, cfg_bonus)
        elif cfg_bonus > 0.0 and bonus <= 0.0:
            bonus = cfg_bonus
    return max(1.0, base_seconds - bonus)

static func _schedule_task(cell_id: int, kind: StringName, bee_id: int, wait: float, on_done: Callable, options: Dictionary = {}) -> bool:
    if _tasks.has(cell_id):
        return false
    var timer: SceneTreeTimer = _create_timer(max(wait, 0.0))
    if timer == null:
        return false
    var opts: Dictionary = {}
    if typeof(options) == TYPE_DICTIONARY:
        opts = options.duplicate(true)
    if not opts.has("auto_release"):
        opts["auto_release"] = true
    var ring: Node = null
    if bool(opts.get("ring", false)):
        ring = _attach_progress_ring(cell_id, max(wait, 0.0))
    _tasks[cell_id] = {
        "timer": timer,
        "bee_id": bee_id,
        "duration": max(wait, 0.0),
        "kind": kind,
        "ring": ring,
        "options": opts
    }
    var ends_at: float = Time.get_unix_time_from_system() + max(wait, 0.0)
    if typeof(Events) == TYPE_OBJECT and bool(opts.get("emit_started", false)):
        Events.task_started.emit(cell_id, kind, bee_id, ends_at)
    timer.timeout.connect(func() -> void:
        _complete_task(cell_id, kind, on_done, true)
    , CONNECT_ONE_SHOT)
    return true

static func _complete_task(cell_id: int, kind: StringName, on_done: Callable, success: bool) -> void:
    if not _tasks.has(cell_id):
        return
    var data: Dictionary = _tasks[cell_id]
    _tasks.erase(cell_id)
    var bee_id: int = int(data.get("bee_id", -1))
    var opts_value: Variant = data.get("options", {})
    var opts: Dictionary = {} if typeof(opts_value) != TYPE_DICTIONARY else opts_value
    var ring: Variant = data.get("ring", null)
    if ring is Node and is_instance_valid(ring):
        (ring as Node).queue_free()
    if bee_id > 0 and bool(opts.get("auto_release", true)):
        GameState.release_bee(bee_id)
    if success and on_done.is_valid():
        on_done.call()
    if typeof(Events) == TYPE_OBJECT and bool(opts.get("emit_finished", false)):
        Events.task_finished.emit(cell_id, kind, bee_id, success)
    if typeof(Events) == TYPE_OBJECT and bool(opts.get("emit_resources_changed", false)):
        Events.resources_changed.emit(GameState.get_resources_snapshot())

static func _create_timer(duration: float) -> SceneTreeTimer:
    var main_loop: MainLoop = Engine.get_main_loop()
    if main_loop is SceneTree:
        return (main_loop as SceneTree).create_timer(max(duration, 0.0))
    return null

static func _attach_progress_ring(cell_id: int, wait: float) -> Node:
    if TASK_PROGRESS_SCENE == null:
        return null
    var main_loop: MainLoop = Engine.get_main_loop()
    if not (main_loop is SceneTree):
        return null
    var tree: SceneTree = main_loop
    var scene: Node = tree.current_scene
    if scene == null:
        return null
    var instance: Node = TASK_PROGRESS_SCENE.instantiate()
    if instance == null:
        return null
    if instance.has_method("setup"):
        instance.call("setup", wait)
    if instance is CanvasItem:
        (instance as CanvasItem).top_level = true
    var center: Variant = _get_cell_center_world(cell_id)
    if typeof(center) == TYPE_VECTOR2 and instance is CanvasItem:
        (instance as CanvasItem).global_position = center
    scene.add_child(instance)
    return instance

static func _get_cell_center_world(cell_id: int) -> Variant:
    var main_loop: MainLoop = Engine.get_main_loop()
    if not (main_loop is SceneTree):
        return Vector2.ZERO
    var tree: SceneTree = main_loop
    var root: Node = tree.current_scene
    if root == null:
        return Vector2.ZERO
    var hive_view: Node = _find_node_with_method(root, StringName("get_cell_center_world"))
    if hive_view != null:
        var result: Variant = hive_view.call("get_cell_center_world", cell_id)
        if typeof(result) == TYPE_VECTOR2:
            return result
    return Vector2.ZERO

static func _find_node_with_method(node: Node, method: StringName) -> Node:
    if node.has_method(method):
        return node
    for child in node.get_children():
        if child is Node:
            var found: Node = _find_node_with_method(child, method)
            if found != null:
                return found
    return null

static func _unlock_neighbor_cells(cell_id: int) -> void:
    for neighbor_id in HiveSystem.get_neighbor_ids(cell_id):
        var state: int = GameState.get_hive_cell_state(neighbor_id, BUILD_STATE_LOCKED)
        if state == BUILD_STATE_LOCKED:
            GameState.set_hive_cell_state(neighbor_id, BUILD_STATE_AVAILABLE)
