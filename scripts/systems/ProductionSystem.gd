extends Node
class_name ProductionSystem

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")

var _timers: Dictionary = {}
var _group_to_cell: Dictionary = {}
var _group_resources: Dictionary = {}
var _paused_groups: Dictionary = {}

func _ready() -> void:
    if not Events.cell_built.is_connected(_on_cell_built):
        Events.cell_built.connect(_on_cell_built)
    if not Events.assignment_changed.is_connected(_on_assignment_changed):
        Events.assignment_changed.connect(_on_assignment_changed)
    if not Events.resources_changed.is_connected(_on_resources_changed):
        Events.resources_changed.connect(_on_resources_changed)
    _initialize_existing_groups()

func refresh_group_for_cell(cell_id: int) -> void:
    _refresh_group(cell_id)

func _initialize_existing_groups() -> void:
    var cells: Dictionary = HiveSystem.get_cells()
    for cell_id in cells.keys():
        _refresh_group(int(cell_id))

func _on_cell_built(cell_id: int, _cell_type: StringName) -> void:
    _refresh_group(cell_id)

func _on_assignment_changed(cell_id: int, _bee_id: int) -> void:
    _refresh_group(cell_id)

func _on_resources_changed(_snapshot: Dictionary) -> void:
    if _paused_groups.is_empty():
        return
    var to_resume: Array[int] = []
    for group_id in _paused_groups.keys():
        var gid: int = int(group_id)
        if _can_group_resume(gid):
            to_resume.append(gid)
    for gid in to_resume:
        _paused_groups.erase(gid)
        var timer: Timer = _timers.get(gid, null)
        if timer:
            timer.start()

func _refresh_group(cell_id: int) -> void:
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        return
    var group_id: int = int(entry.get("group_id", cell_id))
    var type_str: String = String(entry.get("type", "Empty"))
    if type_str == "Empty" or type_str == "Brood":
        _remove_group(group_id)
        return
    var cell_type: StringName = StringName(type_str)
    var produces: Dictionary = ConfigDB.get_cell_production(cell_type)
    if produces.is_empty():
        _remove_group(group_id)
        return
    var tick_seconds: float = ConfigDB.get_cell_tick_seconds(cell_type)
    if tick_seconds <= 0.0:
        _remove_group(group_id)
        return
    var timer: Timer = _ensure_timer(group_id)
    _group_to_cell[group_id] = cell_id
    _group_resources[group_id] = produces.duplicate(true)
    timer.stop()
    timer.wait_time = tick_seconds
    var assigned: Array = entry.get("assigned", [])
    if assigned.is_empty():
        _paused_groups.erase(group_id)
        return
    if _paused_groups.has(group_id):
        if _can_group_resume(group_id):
            _paused_groups.erase(group_id)
            timer.start()
    else:
        timer.start()

func _ensure_timer(group_id: int) -> Timer:
    var timer: Timer = _timers.get(group_id, null)
    if timer:
        return timer
    timer = Timer.new()
    timer.one_shot = false
    timer.autostart = false
    timer.stop()
    timer.timeout.connect(func() -> void:
        _on_timer_timeout(group_id)
    )
    add_child(timer)
    _timers[group_id] = timer
    return timer

func _on_timer_timeout(group_id: int) -> void:
    _process_group_tick(group_id)

func _process_group_tick(group_id: int) -> void:
    var cell_id: int = int(_group_to_cell.get(group_id, -1))
    if cell_id == -1:
        _remove_group(group_id)
        return
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        _remove_group(group_id)
        return
    var type_str: String = String(entry.get("type", "Empty"))
    if type_str == "Empty" or type_str == "Brood":
        _remove_group(group_id)
        return
    var produces: Dictionary = _group_resources.get(group_id, {})
    if produces.is_empty():
        _remove_group(group_id)
        return
    var assigned: Array = entry.get("assigned", [])
    var assigned_count: int = assigned.size()
    if assigned_count <= 0:
        var timer: Timer = _timers.get(group_id, null)
        if timer:
            timer.stop()
        _paused_groups.erase(group_id)
        return
    var efficiency_sum: float = 0.0
    for data in assigned:
        if typeof(data) == TYPE_DICTIONARY:
            efficiency_sum += float(data.get("efficiency", 0))
    var size: int = int(entry.get("size", 1))
    var output_factor: float = 1.0 + 0.6 * float(max(0, size - 1))
    var produced_any := false
    var blocked_by_cap := false
    for resource_id in produces.keys():
        var base_amount: float = float(produces[resource_id])
        var amount_float: float = base_amount * output_factor * float(assigned_count) + efficiency_sum
        var amount: int = int(floor(amount_float))
        if amount <= 0:
            continue
        var res_id: StringName = resource_id if typeof(resource_id) == TYPE_STRING_NAME else StringName(String(resource_id))
        if GameState.can_add(res_id, amount):
            GameState.add_resource(res_id, amount)
            Events.production_tick.emit(cell_id, res_id, amount)
            produced_any = true
        else:
            blocked_by_cap = true
    if produced_any:
        _paused_groups.erase(group_id)
        return
    if blocked_by_cap:
        _pause_group_for_cap(group_id)

func _pause_group_for_cap(group_id: int) -> void:
    var timer: Timer = _timers.get(group_id, null)
    if timer:
        timer.stop()
    _paused_groups[group_id] = true

func _remove_group(group_id: int) -> void:
    if _timers.has(group_id):
        var timer: Timer = _timers[group_id]
        timer.stop()
        timer.queue_free()
        _timers.erase(group_id)
    _group_to_cell.erase(group_id)
    _group_resources.erase(group_id)
    _paused_groups.erase(group_id)

func _can_group_resume(group_id: int) -> bool:
    var cell_id: int = int(_group_to_cell.get(group_id, -1))
    if cell_id == -1:
        return false
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.is_empty():
        return false
    var assigned: Array = entry.get("assigned", [])
    if assigned.is_empty():
        return false
    var produces: Dictionary = _group_resources.get(group_id, {})
    if produces.is_empty():
        return false
    var efficiency_sum: float = 0.0
    for data in assigned:
        if typeof(data) == TYPE_DICTIONARY:
            efficiency_sum += float(data.get("efficiency", 0))
    var size: int = int(entry.get("size", 1))
    var output_factor: float = 1.0 + 0.6 * float(max(0, size - 1))
    var assigned_count: int = assigned.size()
    for resource_id in produces.keys():
        var base_amount: float = float(produces[resource_id])
        var amount_float: float = base_amount * output_factor * float(assigned_count) + efficiency_sum
        var amount: int = int(floor(amount_float))
        if amount <= 0:
            continue
        var res_id: StringName = resource_id if typeof(resource_id) == TYPE_STRING_NAME else StringName(String(resource_id))
        if GameState.can_add(res_id, amount):
            return true
    return false
