extends Node

var _rng := RandomNumberGenerator.new()
var _tick_timer: Timer
var _threat_cfg: Dictionary = {}
var _boss_cfg: Dictionary = {}
var _boss_in_progress: bool = false

func _ready() -> void:
    _rng.randomize()
    _reload_configs()
    _start_tick_timer()
    if typeof(Events) == TYPE_OBJECT and not Events.game_over.is_connected(_on_game_over):
        Events.game_over.connect(_on_game_over)

func _reload_configs() -> void:
    _threat_cfg = ConfigDB.get_threats_cfg()
    _boss_cfg = ConfigDB.get_boss_cfg()

func _start_tick_timer() -> void:
    if _tick_timer:
        return
    _tick_timer = Timer.new()
    _tick_timer.wait_time = 1.0
    _tick_timer.one_shot = false
    _tick_timer.autostart = true
    _tick_timer.timeout.connect(_tick)
    add_child(_tick_timer)

func _tick() -> void:
    if GameState.is_game_over():
        return
    var now := Time.get_unix_time_from_system()
    if _should_start_boss(now):
        _start_boss_warning(now)
        return
    if _boss_in_progress:
        return
    if GameState.active_threat != null:
        return
    var min_gap: float = _get_min_spawn_gap()
    if now < GameState.last_threat_end_time + min_gap:
        return
    _spawn_next_threat(now)

func _should_start_boss(now: float) -> bool:
    if GameState.boss_started:
        return false
    if _boss_in_progress:
        return false
    if GameState.active_threat != null:
        return false
    var hard_cap: float = float(_boss_cfg.get("hard_cap_seconds", 0.0))
    if hard_cap <= 0.0:
        return false
    return GameState.get_run_elapsed_seconds() >= hard_cap

func _start_boss_warning(now: float) -> void:
    _boss_in_progress = true
    GameState.boss_started = true
    var warning_seconds: float = float(_boss_cfg.get("warning_seconds", 0.0))
    var end_time: float = now + warning_seconds
    GameState.boss_warning_end_time = end_time
    Events.boss_warning_started.emit(end_time)
    var wait_time: float = max(0.0, warning_seconds)
    var timer: SceneTreeTimer = get_tree().create_timer(wait_time)
    timer.timeout.connect(_boss_run_phases)

func _boss_run_phases() -> void:
    if GameState.is_game_over():
        _boss_in_progress = false
        return
    var phases: Array = _boss_cfg.get("phases", [])
    var phase_gap: float = float(_boss_cfg.get("phase_gap_seconds", 0.0))
    for i in range(phases.size()):
        var power_value: Variant = phases[i]
        var power: int = 0
        if typeof(power_value) == TYPE_FLOAT or typeof(power_value) == TYPE_INT:
            power = int(round(float(power_value)))
        Events.boss_phase_started.emit(i + 1, power)
        var defense: int = GameState.get_effective_defense()
        var success: bool = defense >= power
        Events.boss_phase_resolved.emit(i + 1, success, power, defense)
        if not success:
            if not GameState.is_game_over():
                Events.game_over.emit("boss")
            GameState.boss_warning_end_time = 0.0
            _boss_in_progress = false
            return
        if i < phases.size() - 1 and phase_gap > 0.0:
            var timer: SceneTreeTimer = get_tree().create_timer(phase_gap)
            await timer.timeout
            if GameState.is_game_over():
                _boss_in_progress = false
                return
    GameState.last_threat_end_time = Time.get_unix_time_from_system()
    GameState.boss_warning_end_time = 0.0
    _boss_in_progress = false

func _spawn_next_threat(now: float) -> void:
    var id_string: String = _weighted_pick()
    if id_string.is_empty():
        return
    var key: String = id_string
    var occurrences: int = int(GameState.threat_counts.get(key, 0))
    var base_power: int = _get_base_threat_power()
    var power: int = _apply_power_growth(base_power, occurrences)
    var warning_seconds: float = _get_warning_seconds()
    var ends_at: float = now + warning_seconds
    GameState.active_threat = {
        "id": id_string,
        "power": power,
        "ends_at": ends_at
    }
    GameState.threat_counts[key] = occurrences + 1
    var preview_power: int = GameState.preview_next_threat_power(power)
    Events.threat_warning_started.emit(StringName(id_string), preview_power, ends_at)
    _arm_resolve_timer(ends_at)

func _arm_resolve_timer(ends_at: float) -> void:
    var wait: float = max(0.0, ends_at - Time.get_unix_time_from_system())
    var timer: SceneTreeTimer = get_tree().create_timer(wait)
    timer.timeout.connect(_resolve_active_threat)

func _resolve_active_threat() -> void:
    var threat_data: Variant = GameState.active_threat
    if threat_data == null:
        return
    if typeof(threat_data) != TYPE_DICTIONARY:
        GameState.active_threat = null
        return
    var threat: Dictionary = threat_data
    var id_value: Variant = threat.get("id", "")
    var id_string: String = String(id_value)
    var base_power: int = int(threat.get("power", 0))
    var resolve_data: Dictionary = GameState.consume_next_threat_modifiers(base_power)
    var final_power: int = int(resolve_data.get("power", base_power))
    var auto_win: bool = bool(resolve_data.get("auto_win", false))
    var defense: int = GameState.get_effective_defense()
    var success: bool = auto_win or defense >= final_power
    Events.threat_resolved.emit(StringName(id_string), success, final_power, defense)
    GameState.last_threat_end_time = Time.get_unix_time_from_system()
    GameState.active_threat = null
    if success:
        Events.threat_cooldown_started.emit(int(round(_get_min_spawn_gap())))
    else:
        if not GameState.is_game_over():
            Events.game_over.emit("threat_" + id_string)

func _weighted_pick() -> String:
    var weights: Dictionary = _threat_cfg.get("weights", {})
    var entries: Array = _threat_cfg.get("list", [])
    var candidates: Array = []
    for entry_value in entries:
        if typeof(entry_value) != TYPE_DICTIONARY:
            continue
        var id_value: Variant = entry_value.get("id", "")
        var id_string: String = String(id_value)
        if id_string.is_empty():
            continue
        var weight_value: Variant = weights.get(id_string, 1.0)
        var weight: float = 1.0
        if typeof(weight_value) == TYPE_FLOAT or typeof(weight_value) == TYPE_INT:
            weight = float(weight_value)
        if weight <= 0.0:
            continue
        candidates.append({"id": id_string, "weight": weight})
    if candidates.is_empty():
        return ""
    var total_weight: float = 0.0
    for candidate in candidates:
        total_weight += float(candidate.get("weight", 0.0))
    if total_weight <= 0.0:
        return candidates[0].get("id", "")
    var pick: float = _rng.randf_range(0.0, total_weight)
    var accum: float = 0.0
    for candidate in candidates:
        accum += float(candidate.get("weight", 0.0))
        if pick <= accum:
            return String(candidate.get("id", ""))
    return String(candidates.back().get("id", ""))

func _get_base_threat_power() -> int:
    var global_cfg: Dictionary = _threat_cfg.get("global", {})
    var value: Variant = global_cfg.get("base_power", 0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return int(round(float(value)))
    return 0

func _apply_power_growth(base_power: int, occurrences: int) -> int:
    var global_cfg: Dictionary = _threat_cfg.get("global", {})
    var growth: String = String(global_cfg.get("power_growth", "x2"))
    if growth == "x2":
        if occurrences <= 0:
            return base_power
        var factor: float = pow(2.0, occurrences)
        return int(round(float(base_power) * factor))
    return base_power

func _get_warning_seconds() -> float:
    var global_cfg: Dictionary = _threat_cfg.get("global", {})
    var value: Variant = global_cfg.get("warning_seconds", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return 0.0

func _get_min_spawn_gap() -> float:
    var global_cfg: Dictionary = _threat_cfg.get("global", {})
    var value: Variant = global_cfg.get("min_spawn_gap_seconds", 0.0)
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return 0.0

func _on_game_over(_reason: String) -> void:
    _boss_in_progress = false
