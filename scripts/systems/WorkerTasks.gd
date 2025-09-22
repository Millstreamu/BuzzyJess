extends Node
class_name WorkerTasks

const DEFAULT_BONUS_TRAIT := StringName("Construction")

static var _tasks: Dictionary = {}

static func has_available_bee(preferred_trait: StringName = StringName("")) -> bool:
    return GameState.find_available_bee(preferred_trait) != -1

static func run(cell_id: int, seconds: float, preferred_trait: StringName = StringName(""), allow_bonus: bool = true, bonus_trait: StringName = DEFAULT_BONUS_TRAIT, bonus_amount: float = 0.0, on_done: Callable = Callable()) -> bool:
    var reservation: Dictionary = GameState.reserve_bee_for_task(preferred_trait)
    if reservation.is_empty():
        return false
    var bee_id: int = int(reservation.get("id", -1))
    var bee_data: Dictionary = reservation.get("bee", {})
    var duration: float = max(0.0, seconds)
    if allow_bonus and bonus_amount > 0.0 and TraitsSystem.bee_has_trait(bee_data, bonus_trait):
        duration = max(1.0, duration - bonus_amount)
    var timer: SceneTreeTimer = _create_timer(duration)
    if timer == null:
        GameState.release_bee_from_task(bee_id)
        return false
    if not _tasks.has(cell_id):
        _tasks[cell_id] = {}
    _tasks[cell_id]["timer"] = timer
    _tasks[cell_id]["bee_id"] = bee_id
    timer.timeout.connect(func() -> void:
        _finish_task(cell_id, on_done)
    , CONNECT_ONE_SHOT)
    return true

static func get_task_timer(cell_id: int) -> SceneTreeTimer:
    if not _tasks.has(cell_id):
        return null
    var data: Dictionary = _tasks[cell_id]
    return data.get("timer", null)

static func _finish_task(cell_id: int, on_done: Callable) -> void:
    if not _tasks.has(cell_id):
        return
    var data: Dictionary = _tasks[cell_id]
    var bee_id: int = int(data.get("bee_id", -1))
    GameState.release_bee_from_task(bee_id)
    _tasks.erase(cell_id)
    if on_done.is_valid():
        on_done.call()

static func _create_timer(duration: float) -> SceneTreeTimer:
    var main_loop: MainLoop = Engine.get_main_loop()
    if main_loop is SceneTree:
        return (main_loop as SceneTree).create_timer(max(0.0, duration))
    return null
