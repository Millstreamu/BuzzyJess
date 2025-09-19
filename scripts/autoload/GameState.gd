extends Node

var resources: Dictionary = {}

var bees: Array[Dictionary] = []
var _bee_lookup: Dictionary = {}

func _ready() -> void:
    _initialize_resources()
    _generate_default_bees()

func can_afford(cost: Dictionary) -> bool:
    for key in cost.keys():
        var amount: float = cost[key]
        var id := String(key)
        var entry: Dictionary = resources.get(id, {})
        var qty: float = float(entry.get("qty", 0))
        if qty < amount:
            return false
    return true

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

func add_resource(resource_id: StringName, amount: int) -> void:
    if amount == 0:
        return
    adjust_resource_quantity(resource_id, amount)

func _generate_default_bees() -> void:
    bees.clear()
    _bee_lookup.clear()
    var colors := [
        Color(0.96, 0.78, 0.28),
        Color(0.87, 0.55, 0.2),
        Color(0.64, 0.72, 0.27),
        Color(0.59, 0.58, 0.83),
        Color(0.45, 0.7, 0.74)
    ]
    for i in colors.size():
        var bee_id := i + 1
        var bee := {
            "id": bee_id,
            "display_name": "Bee %d" % bee_id,
            "icon": _make_bee_icon(colors[i]),
            "assigned_group": -1
        }
        bees.append(bee)
        _bee_lookup[bee_id] = bee

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
