extends Node

var resources: Dictionary = {
    "Comb": 40,
    "Honey": 30,
    "Pollen": 30,
    "NectarCommon": 25,
    "PetalRed": 10
}

var bees: Array[Dictionary] = []
var _bee_lookup: Dictionary = {}

func _ready() -> void:
    _generate_default_bees()

func can_afford(cost: Dictionary) -> bool:
    for key in cost.keys():
        var amount: float = cost[key]
        if resources.get(key, 0) < amount:
            return false
    return true

func spend(cost: Dictionary) -> bool:
    if not can_afford(cost):
        return false
    for key in cost.keys():
        resources[key] = resources.get(key, 0) - cost[key]
    return true

func get_resources_snapshot() -> Dictionary:
    return resources.duplicate(true)

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
