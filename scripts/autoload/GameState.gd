extends Node

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")

const DEFAULT_QUEEN_MODIFIERS := {
    "brood_extra_bees": 0,
    "harvest_bee_cost_delta": 0,
    "harvest_bee_cost_min": 1,
    "honey_vat_refund_nectar_common": 0
}

var resources: Dictionary = {}

var bees: Array[Dictionary] = []
var _bee_lookup: Dictionary = {}

var _reserved_gatherers: int = 0

var hive_cell_states: Dictionary = {}

var queen_id: StringName = StringName("")
var modifiers: Dictionary = {}
var defense_meter: int = 0
var last_threat_end_time: float = 0.0
var threat_counts: Dictionary = {}
var active_threat: Variant = null
var run_start_time: float = 0.0
var boss_started: bool = false
var boss_warning_end_time: float = 0.0
var _game_over_reason: String = ""
var _game_over_time: float = 0.0

const DEFAULT_BEE_COLORS := [
    Color(0.96, 0.78, 0.28),
    Color(0.87, 0.55, 0.2),
    Color(0.64, 0.72, 0.27),
    Color(0.59, 0.58, 0.83),
    Color(0.45, 0.7, 0.74)
]

var swarm_points: int = 0
var _next_bee_id: int = 1
var _next_bee_color_index: int = 0

func _ready() -> void:
    _reserved_gatherers = 0
    hive_cell_states.clear()
    reset_queen_selection()
    _initialize_resources()
    _generate_default_bees()
    _connect_event_listeners()
    run_start_time = Time.get_unix_time_from_system()
    defense_meter = 0
    last_threat_end_time = run_start_time
    threat_counts.clear()
    active_threat = null
    boss_started = false
    boss_warning_end_time = 0.0
    _game_over_reason = ""
    _game_over_time = 0.0
    if typeof(Events) == TYPE_OBJECT:
        if not Events.game_over.is_connected(_on_game_over):
            Events.game_over.connect(_on_game_over)
        Events.defense_meter_changed.emit(defense_meter)

func reset_queen_selection() -> void:
    queen_id = StringName("")
    _reset_queen_modifiers()

func _reset_queen_modifiers() -> void:
    modifiers.clear()
    for key in DEFAULT_QUEEN_MODIFIERS.keys():
        modifiers[key] = DEFAULT_QUEEN_MODIFIERS[key]

func can_afford(cost: Dictionary) -> bool:
    for key in cost.keys():
        var amount: float = cost[key]
        var id := String(key)
        var entry: Dictionary = resources.get(id, {})
        var qty: float = float(entry.get("qty", 0))
        if qty < amount:
            return false
    return true

func can_spend(cost: Dictionary) -> bool:
    return can_afford(cost)

func spend(cost: Dictionary) -> bool:
    if not can_afford(cost):
        return false
    for key in cost.keys():
        var id := StringName(String(key))
        var entry: Dictionary = _get_resource_entry(id)
        var qty: float = float(entry.get("qty", 0))
        var amount: float = float(cost[key])
        entry["qty"] = max(0, int(round(qty - amount)))
        resources[String(id)] = entry
    _emit_resources_changed()
    return true

func get_resources_snapshot() -> Dictionary:
    var snap: Dictionary = {}
    for key in resources.keys():
        var id := StringName(key)
        var entry: Dictionary = resources[key]
        snap[id] = {
            "qty": int(entry.get("qty", 0)),
            "cap": int(entry.get("cap", 0)),
            "display_name": entry.get("display_name", String(key)),
            "short_name": entry.get("short_name", entry.get("display_name", String(key)))
        }
    return snap

func get_available_bees() -> Array:
    var available: Array = []
    for bee in bees:
        if bee.get("assigned_group", -1) == -1:
            available.append(bee.duplicate(true))
    return available

func get_bee_by_id(bee_id: int) -> Dictionary:
    var bee: Dictionary = _bee_lookup.get(bee_id, {})
    return bee.duplicate(true) if not bee.is_empty() else {}

func assign_bee_to_building(bee_id: int, group_id: int) -> Dictionary:
    if not _bee_lookup.has(bee_id):
        return {}
    var bee: Dictionary = _bee_lookup[bee_id]
    bee["assigned_group"] = group_id
    return bee.duplicate(true)

func get_bee_icon(bee_id: int) -> Texture2D:
    var bee: Dictionary = _bee_lookup.get(bee_id, {})
    return bee.get("icon", null)

func unassign_bee(bee_id: int) -> void:
    if not _bee_lookup.has(bee_id):
        return
    var bee: Dictionary = _bee_lookup[bee_id]
    bee["assigned_group"] = -1

func _initialize_resources() -> void:
    resources.clear()
    var ids: Array[StringName] = ConfigDB.get_resource_ids()
    for id in ids:
        var entry: Dictionary = _default_resource_entry(id)
        entry["qty"] = ConfigDB.get_resource_initial(id)
        resources[String(id)] = entry
    _emit_resources_changed()

func add_bee() -> int:
    var bee_id: int = _next_bee_id
    _next_bee_id += 1
    var color: Color = _get_next_bee_color()
    var bee: Dictionary = _create_bee_entry(bee_id, color)
    bees.append(bee)
    _bee_lookup[bee_id] = bee
    inc_swarm(1)
    _emit_bees_changed()
    return bee_id

func get_bees_snapshot() -> Array:
    var snapshot: Array = []
    for bee in bees:
        snapshot.append(bee.duplicate(true))
    return snapshot

func inc_swarm(amount: int) -> void:
    if amount == 0:
        return
    swarm_points = max(0, swarm_points + amount)

func set_resource_quantity(resource_id: StringName, amount: int) -> void:
    var entry: Dictionary = _get_resource_entry(resource_id)
    var cap: int = int(entry.get("cap", 0))
    if cap > 0:
        entry["qty"] = clamp(amount, 0, cap)
    else:
        entry["qty"] = max(amount, 0)
    resources[String(resource_id)] = entry
    _emit_resources_changed()

func adjust_resource_quantity(resource_id: StringName, delta: int) -> void:
    var entry: Dictionary = _get_resource_entry(resource_id)
    var cap: int = int(entry.get("cap", 0))
    var qty: int = int(entry.get("qty", 0)) + delta
    if cap > 0:
        qty = clamp(qty, 0, cap)
    else:
        qty = max(qty, 0)
    entry["qty"] = qty
    resources[String(resource_id)] = entry
    _emit_resources_changed()

func set_resource_capacity(resource_id: StringName, capacity: int) -> void:
    var entry: Dictionary = _get_resource_entry(resource_id)
    entry["cap"] = max(capacity, 0)
    if entry.get("qty", 0) > entry.get("cap", 0) and entry.get("cap", 0) > 0:
        entry["qty"] = int(entry.get("cap", 0))
    resources[String(resource_id)] = entry
    _emit_resources_changed()

func _emit_resources_changed() -> void:
    Events.resources_changed.emit(get_resources_snapshot())

func _get_resource_entry(resource_id: StringName) -> Dictionary:
    var key := String(resource_id)
    var entry: Dictionary = resources.get(key, {}).duplicate(true)
    if entry.is_empty():
        entry = _default_resource_entry(resource_id)
    if not entry.has("display_name"):
        entry["display_name"] = ConfigDB.get_resource_display_name(resource_id)
    if not entry.has("short_name"):
        entry["short_name"] = ConfigDB.get_resource_short_name(resource_id)
    if int(entry.get("cap", 0)) == 0:
        var cap := ConfigDB.get_resource_cap(resource_id)
        if cap > 0:
            entry["cap"] = cap
    return entry

func _default_resource_entry(resource_id: StringName) -> Dictionary:
    return {
        "qty": 0,
        "cap": ConfigDB.get_resource_cap(resource_id),
        "display_name": ConfigDB.get_resource_display_name(resource_id),
        "short_name": ConfigDB.get_resource_short_name(resource_id)
    }

func can_add(resource_id: StringName, amount: int) -> bool:
    if amount <= 0:
        return true
    var entry: Dictionary = _get_resource_entry(resource_id)
    var cap: int = int(entry.get("cap", 0))
    if cap <= 0:
        return true
    var qty: int = int(entry.get("qty", 0))
    return qty + amount <= cap

func space_left_for(resource_id: StringName) -> int:
    var entry: Dictionary = _get_resource_entry(resource_id)
    var cap: int = int(entry.get("cap", 0))
    if cap <= 0:
        return -1
    var qty: int = int(entry.get("qty", 0))
    return max(cap - qty, 0)

func set_hive_cell_state(cell_id: int, state: int) -> void:
    hive_cell_states[cell_id] = state

func get_hive_cell_state(cell_id: int, default_value: int = 0) -> int:
    return int(hive_cell_states.get(cell_id, default_value))

func get_hive_cell_states() -> Dictionary:
    return hive_cell_states.duplicate(true)

func add_resource(resource_id: StringName, amount: int) -> void:
    if amount == 0:
        return
    adjust_resource_quantity(resource_id, amount)

func get_effective_defense() -> int:
    var base: int = max(defense_meter, 0)
    var bonus_value: Variant = modifiers.get("defense_meter_bonus", 0)
    if typeof(bonus_value) == TYPE_FLOAT or typeof(bonus_value) == TYPE_INT:
        base += int(round(float(bonus_value)))
    return max(base, 0)

func add_defense(amount: int) -> void:
    if amount == 0:
        return
    defense_meter = max(defense_meter + amount, 0)
    if typeof(Events) == TYPE_OBJECT:
        Events.defense_meter_changed.emit(defense_meter)

func clear_defense_for_debug() -> void:
    defense_meter = 0
    if typeof(Events) == TYPE_OBJECT:
        Events.defense_meter_changed.emit(defense_meter)

func preview_next_threat_power(base_power: int) -> int:
    var adjusted: float = float(max(base_power, 0))
    var delta_value: Variant = modifiers.get("next_threat_power_delta", 0.0)
    if typeof(delta_value) == TYPE_FLOAT or typeof(delta_value) == TYPE_INT:
        adjusted *= 1.0 + float(delta_value)
    var flat_value: Variant = modifiers.get("next_threat_power_flat", 0)
    if typeof(flat_value) == TYPE_FLOAT or typeof(flat_value) == TYPE_INT:
        adjusted += float(flat_value)
    return max(0, int(round(adjusted)))

func consume_next_threat_modifiers(base_power: int) -> Dictionary:
    var result := {
        "power": preview_next_threat_power(base_power),
        "auto_win": false
    }
    var auto_value: Variant = modifiers.get("next_threat_auto_win", false)
    if typeof(auto_value) == TYPE_BOOL:
        result["auto_win"] = auto_value
    elif typeof(auto_value) == TYPE_INT:
        result["auto_win"] = int(auto_value) != 0
    if modifiers.has("next_threat_power_delta"):
        modifiers.erase("next_threat_power_delta")
    if modifiers.has("next_threat_power_flat"):
        modifiers.erase("next_threat_power_flat")
    if modifiers.has("next_threat_auto_win"):
        modifiers.erase("next_threat_auto_win")
    return result

func get_run_elapsed_seconds() -> float:
    return Time.get_unix_time_from_system() - run_start_time

func is_game_over() -> bool:
    return not _game_over_reason.is_empty()

func get_game_over_reason() -> String:
    return _game_over_reason

func get_free_gatherers() -> int:
    var total_assigned: int = _get_total_assigned_gatherers()
    return max(total_assigned - _reserved_gatherers, 0)

func reserve_gatherers(amount: int) -> bool:
    if amount <= 0:
        return true
    if get_free_gatherers() < amount:
        return false
    _reserved_gatherers += amount
    if typeof(Events) == TYPE_OBJECT:
        Events.gatherer_bees_available_changed.emit(get_free_gatherers())
    return true

func free_gatherers(amount: int) -> void:
    if amount <= 0:
        return
    _reserved_gatherers = max(0, _reserved_gatherers - amount)
    if typeof(Events) == TYPE_OBJECT:
        Events.gatherer_bees_available_changed.emit(get_free_gatherers())

func apply_queen_effects(effects: Dictionary) -> void:
    _reset_queen_modifiers()
    for key in effects.keys():
        var key_string: String = String(key)
        var value: Variant = effects.get(key, 0)
        if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
            modifiers[key_string] = int(round(float(value)))
        else:
            modifiers[key_string] = value
    if typeof(Events) == TYPE_OBJECT:
        Events.queen_selected.emit(queen_id, modifiers.duplicate(true))

func get_harvest_bee_requirement(base_required_bees: int) -> int:
    var delta: int = int(modifiers.get("harvest_bee_cost_delta", DEFAULT_QUEEN_MODIFIERS["harvest_bee_cost_delta"]))
    var minimum: int = int(modifiers.get("harvest_bee_cost_min", DEFAULT_QUEEN_MODIFIERS["harvest_bee_cost_min"]))
    var required: int = base_required_bees + delta
    required = max(minimum, required)
    return max(required, 0)

func _get_total_assigned_gatherers() -> int:
    var total: int = 0
    var cells: Dictionary = HiveSystem.get_cells()
    for entry in cells.values():
        var type_string: String = String(entry.get("type", ""))
        if type_string != "GatheringHut":
            continue
        var assigned: Variant = entry.get("assigned", [])
        if typeof(assigned) == TYPE_ARRAY:
            total += assigned.size()
    return total

func _connect_event_listeners() -> void:
    if typeof(Events) != TYPE_OBJECT:
        return
    if not Events.assignment_changed.is_connected(_on_assignment_changed):
        Events.assignment_changed.connect(_on_assignment_changed)
    if not Events.cell_converted.is_connected(_on_cell_converted):
        Events.cell_converted.connect(_on_cell_converted)

func _on_game_over(reason: String) -> void:
    if _game_over_reason.is_empty():
        _game_over_reason = String(reason)
        _game_over_time = Time.get_unix_time_from_system()

func _on_assignment_changed(cell_id: int, _bee_id: int) -> void:
    var type_string: String = HiveSystem.get_cell_type(cell_id)
    if type_string != "GatheringHut":
        return
    Events.gatherer_bees_available_changed.emit(get_free_gatherers())

func _on_cell_converted(_cell_id: int, _new_type: StringName) -> void:
    Events.gatherer_bees_available_changed.emit(get_free_gatherers())

func _generate_default_bees() -> void:
    bees.clear()
    _bee_lookup.clear()
    swarm_points = 0
    _next_bee_id = 1
    _next_bee_color_index = 0
    for color in DEFAULT_BEE_COLORS:
        var bee_id: int = _next_bee_id
        _next_bee_id += 1
        var bee: Dictionary = _create_bee_entry(bee_id, color)
        bees.append(bee)
        _bee_lookup[bee_id] = bee
        _next_bee_color_index += 1
    _emit_bees_changed()

func _make_bee_icon(color: Color) -> Texture2D:
    var size := 36
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var center := Vector2(size, size) * 0.5
    var radius := float(size) * 0.4
    for y in size:
        for x in size:
            var pos := Vector2(float(x) + 0.5, float(y) + 0.5)
            if pos.distance_to(center) <= radius:
                image.set_pixel(x, y, color)
    return ImageTexture.create_from_image(image)

func _create_bee_entry(bee_id: int, color: Color) -> Dictionary:
    return {
        "id": bee_id,
        "display_name": "Bee %d" % bee_id,
        "icon": _make_bee_icon(color),
        "assigned_group": -1
    }

func _get_next_bee_color() -> Color:
    if DEFAULT_BEE_COLORS.is_empty():
        return Color(0.9, 0.8, 0.3)
    var index: int = _next_bee_color_index % DEFAULT_BEE_COLORS.size()
    var color: Color = DEFAULT_BEE_COLORS[index]
    _next_bee_color_index += 1
    return color

func _emit_bees_changed() -> void:
    if typeof(Events) == TYPE_OBJECT:
        Events.bees_changed.emit(get_bees_snapshot())
