extends Node
class_name DefenseSystem

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")
const GUARD_POST_TYPE := StringName("GuardPost")

var _timers: Dictionary = {}
var _group_to_cell: Dictionary = {}

func _ready() -> void:
    _initialize_existing_posts()
    if typeof(Events) == TYPE_OBJECT:
        if not Events.cell_built.is_connected(_on_cell_built):
            Events.cell_built.connect(_on_cell_built)
        if not Events.assignment_changed.is_connected(_on_assignment_changed):
            Events.assignment_changed.connect(_on_assignment_changed)
        if not Events.cell_converted.is_connected(_on_cell_converted):
            Events.cell_converted.connect(_on_cell_converted)
        if not Events.game_over.is_connected(_on_game_over):
            Events.game_over.connect(_on_game_over)

func _initialize_existing_posts() -> void:
    var cells: Dictionary = HiveSystem.get_cells()
    for cell_id in cells.keys():
        _refresh_post(int(cell_id))

func _on_cell_built(cell_id: int, _cell_type: StringName) -> void:
    _refresh_post(cell_id)

func _on_assignment_changed(cell_id: int, _bee_id: int) -> void:
    _refresh_post(cell_id)

func _on_cell_converted(cell_id: int, _new_type: StringName) -> void:
    _refresh_post(cell_id)

func _on_game_over(_reason: String) -> void:
    for timer in _timers.values():
        if timer is Timer:
            timer.stop()

func _refresh_post(cell_id: int) -> void:
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        _remove_post(cell_id)
        return
    var type_string: String = String(entry.get("type", "Empty"))
    var group_id: int = int(entry.get("group_id", cell_id))
    if type_string != String(GUARD_POST_TYPE):
        _remove_group(group_id)
        return
    var timer: Timer = _ensure_timer(group_id)
    _group_to_cell[group_id] = cell_id
    var assigned: Array = entry.get("assigned", [])
    var has_guards: bool = not assigned.is_empty()
    timer.stop()
    timer.wait_time = _get_tick_seconds(entry)
    if has_guards and not GameState.is_game_over():
        timer.start()

func _ensure_timer(group_id: int) -> Timer:
    var timer: Timer = _timers.get(group_id, null)
    if timer:
        return timer
    timer = Timer.new()
    timer.wait_time = 5.0
    timer.one_shot = false
    timer.autostart = false
    timer.timeout.connect(func() -> void:
        _process_guard_tick(group_id)
    )
    add_child(timer)
    _timers[group_id] = timer
    return timer

func _process_guard_tick(group_id: int) -> void:
    if GameState.is_game_over():
        var timer: Timer = _timers.get(group_id, null)
        if timer:
            timer.stop()
        return
    var cell_id: int = int(_group_to_cell.get(group_id, -1))
    if cell_id == -1:
        _remove_group(group_id)
        return
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        _remove_group(group_id)
        return
    var type_string: String = String(entry.get("type", "Empty"))
    if type_string != String(GUARD_POST_TYPE):
        _remove_group(group_id)
        return
    var assigned: Array = entry.get("assigned", [])
    var assigned_count: int = assigned.size()
    if assigned_count <= 0:
        var timer: Timer = _timers.get(group_id, null)
        if timer:
            timer.stop()
        return
    var size: int = int(entry.get("size", 1))
    var per_guard: int = max(size, 1)
    var amount: int = assigned_count * per_guard
    if amount <= 0:
        return
    GameState.add_defense(amount)

func _remove_post(cell_id: int) -> void:
    for group_id in _group_to_cell.keys():
        if int(_group_to_cell[group_id]) == cell_id:
            _remove_group(int(group_id))
            return

func _remove_group(group_id: int) -> void:
    var timer: Timer = _timers.get(group_id, null)
    if timer:
        timer.stop()
        timer.queue_free()
        _timers.erase(group_id)
    _group_to_cell.erase(group_id)

func _get_tick_seconds(entry: Dictionary) -> float:
    var base: float = ConfigDB.get_cell_tick_seconds(GUARD_POST_TYPE)
    if base <= 0.0:
        base = 5.0
    var size: int = int(entry.get("size", 1))
    var reduction: int = clamp(size - 1, 0, 2)
    return max(1.0, base - float(reduction))

*** End File
