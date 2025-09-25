# -----------------------------------------------------------------------------
# File: scripts/systems/CandleHallSystem.gd
# Purpose: Drives Candle Hall rituals that unlock abilities over time
# Depends: ConfigDB, AbilitySystem, CostPolicy, Events, UIFx
# Notes: Charges Comb upfront and tracks ritual completion timers per cell
# -----------------------------------------------------------------------------

## CandleHallSystem
## Handles starting rituals, tracking progress, and emitting ability rewards.
extends Node

var _active: Dictionary = {}
var _unlocked: bool = false

func _ready() -> void:
    _active.clear()
    _unlocked = false
    if typeof(Events) == TYPE_OBJECT:
        if not Events.cell_converted.is_connected(_on_cell_converted):
            Events.cell_converted.connect(_on_cell_converted)

func start_ritual(cell_id: int) -> bool:
    if cell_id < 0:
        return false
    _cleanup_finished()
    if is_ritual_active(cell_id):
        UIFx.flash_deny()
        UIFx.show_toast("Ritual already in progress")
        return false
    if AbilitySystem.at_capacity():
        UIFx.flash_deny()
        var max_count: int = AbilitySystem.max_size()
        UIFx.show_toast("Abilities full (%d). Use one first." % max(1, max_count))
        return false
    var cfg: Dictionary = ConfigDB.abilities_ritual_cfg()
    var comb_cost: int = 0
    var comb_value: Variant = cfg.get("comb_cost", 0)
    if typeof(comb_value) == TYPE_FLOAT or typeof(comb_value) == TYPE_INT:
        comb_cost = max(int(round(float(comb_value))), 0)
    var spend_cost: Dictionary = {}
    if comb_cost > 0:
        spend_cost[StringName("Comb")] = comb_cost
        if not CostPolicy.can_afford(spend_cost):
            UIFx.flash_deny()
            UIFx.show_toast("Need %d Comb" % comb_cost)
            return false
        if not CostPolicy.try_charge(spend_cost):
            UIFx.flash_deny()
            UIFx.show_toast("Need %d Comb" % comb_cost)
            return false
    var seconds_value: Variant = cfg.get("seconds", 0.0)
    var secs: float = 0.0
    if typeof(seconds_value) == TYPE_FLOAT or typeof(seconds_value) == TYPE_INT:
        secs = max(float(seconds_value), 0.0)
    var ends_at: float = Time.get_unix_time_from_system() + secs
    var entry: Dictionary = {"ends_at": ends_at}
    if secs > 0.0:
        var timer := Timer.new()
        timer.one_shot = true
        timer.wait_time = secs
        add_child(timer)
        timer.timeout.connect(func() -> void:
            _complete_ritual(cell_id)
        , CONNECT_ONE_SHOT)
        timer.start()
        entry["timer"] = timer
    _active[cell_id] = entry
    if typeof(Events) == TYPE_OBJECT:
        Events.resources_changed.emit(GameState.get_resources_snapshot())
        Events.ritual_started.emit(cell_id, ends_at)
    if secs <= 0.0:
        _complete_ritual(cell_id)
    return true

func is_ritual_active(cell_id: int) -> bool:
    if not _active.has(cell_id):
        return false
    var entry: Dictionary = _active.get(cell_id, {})
    if entry.is_empty():
        _active.erase(cell_id)
        return false
    var timer: Timer = entry.get("timer", null)
    if timer:
        if not is_instance_valid(timer) or timer.time_left <= 0.0:
            _active.erase(cell_id)
            return false
    var ends_value: Variant = entry.get("ends_at", 0.0)
    var ends_at: float = 0.0
    if typeof(ends_value) == TYPE_FLOAT or typeof(ends_value) == TYPE_INT:
        ends_at = float(ends_value)
    if ends_at <= Time.get_unix_time_from_system():
        _active.erase(cell_id)
        return false
    return true

func ritual_end_time(cell_id: int) -> float:
    if not _active.has(cell_id):
        return 0.0
    var entry: Dictionary = _active.get(cell_id, {})
    var ends_value: Variant = entry.get("ends_at", 0.0)
    if typeof(ends_value) == TYPE_FLOAT or typeof(ends_value) == TYPE_INT:
        return float(ends_value)
    return 0.0

func unlocked() -> bool:
    return _unlocked

func _complete_ritual(cell_id: int) -> void:
    var entry: Dictionary = _active.get(cell_id, {})
    if not entry.is_empty():
        var timer: Timer = entry.get("timer", null)
        if timer and is_instance_valid(timer):
            timer.stop()
            timer.queue_free()
    _active.erase(cell_id)
    var id: StringName = AbilitySystem.add_random_from_pool()
    if id != StringName(""):
        if typeof(Events) == TYPE_OBJECT:
            Events.ritual_completed.emit(cell_id, id)
        UIFx.show_toast("New ability added")
    else:
        if typeof(Events) == TYPE_OBJECT:
            Events.ritual_completed.emit(cell_id, StringName(""))

func _cleanup_finished() -> void:
    var to_complete: Array[int] = []
    var now: float = Time.get_unix_time_from_system()
    for key in _active.keys():
        var entry: Dictionary = _active[key]
        var ends_value: Variant = entry.get("ends_at", 0.0)
        var ends_at: float = 0.0
        if typeof(ends_value) == TYPE_FLOAT or typeof(ends_value) == TYPE_INT:
            ends_at = float(ends_value)
        if ends_at <= now:
            to_complete.append(int(key))
    for cell_id in to_complete:
        _complete_ritual(cell_id)

func _on_cell_converted(cell_id: int, new_type: StringName) -> void:
    var type_name: StringName = new_type if typeof(new_type) == TYPE_STRING_NAME else StringName(String(new_type))
    if type_name == StringName("CandleHall"):
        _ensure_unlocked()
    else:
        if _active.has(cell_id):
            var entry: Dictionary = _active[cell_id]
            var timer: Timer = entry.get("timer", null)
            if timer and is_instance_valid(timer):
                timer.stop()
                timer.queue_free()
            _active.erase(cell_id)

func _ensure_unlocked() -> void:
    if _unlocked:
        return
    _unlocked = true
    if typeof(Events) == TYPE_OBJECT:
        Events.abilities_unlocked.emit()
    UIFx.show_toast("Abilities unlocked")

