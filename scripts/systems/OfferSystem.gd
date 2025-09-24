extends Node
class_name OfferSystem

var visible_harvests: Array[Dictionary] = []
var visible_contracts: Array[Dictionary] = []
var last_ids: Dictionary = {
    "harvests": [],
    "item_quests": []
}

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    if typeof(Events) == TYPE_OBJECT:
        if not Events.queen_selected.is_connected(_on_modifiers_changed):
            Events.queen_selected.connect(_on_modifiers_changed)
    _refill_all()

func get_visible(kind: StringName) -> Array[Dictionary]:
    var source: Array[Dictionary] = visible_harvests if kind == StringName("harvests") else visible_contracts
    var list: Array[Dictionary] = []
    for entry in source:
        list.append(entry.duplicate(true))
    return list

func is_visible(kind: StringName, id: StringName) -> bool:
    var source: Array[Dictionary] = visible_harvests if kind == StringName("harvests") else visible_contracts
    for entry in source:
        if StringName(entry.get("id", StringName(""))) == id:
            return true
    return false

func get_offer(kind: StringName, id: StringName) -> Dictionary:
    return ConfigDB.offers_get(kind, id)

func refresh_all() -> void:
    _refill_all()

func refill_one(kind: StringName, used_id: StringName) -> void:
    _record_last_id(kind, used_id)
    var desired: int = GameState.current_harvest_slots() if kind == StringName("harvests") else GameState.current_contract_slots()
    var list: Array[Dictionary] = visible_harvests if kind == StringName("harvests") else visible_contracts
    for i in range(list.size() - 1, -1, -1):
        if StringName(list[i].get("id", StringName(""))) == used_id:
            list.remove_at(i)
    while desired >= 0 and list.size() > desired:
        var removed: Dictionary = list.pop_back()
        var removed_id: StringName = removed.get("id", StringName(""))
        _record_last_id(kind, removed_id)
    var attempts: int = 0
    while list.size() < desired:
        var exclude: Array[StringName] = _current_ids(kind)
        exclude.append(used_id)
        var history: Array = last_ids.get(String(kind), [])
        for entry in history:
            exclude.append(StringName(String(entry)))
        var offer: Dictionary = _pick_one(kind, exclude)
        attempts += 1
        if offer.is_empty():
            break
        list.append(offer)
        exclude.append(StringName(offer.get("id", StringName(""))))
        if attempts > 10 * desired:
            break
    _set_visible_list(kind, list)
    _emit_refresh(kind)

func _on_modifiers_changed(_queen_id: StringName, _modifiers: Dictionary) -> void:
    _refill_all()

func _refill_all() -> void:
    var harvest_slots: int = max(GameState.current_harvest_slots(), 0)
    var contract_slots: int = max(GameState.current_contract_slots(), 0)
    visible_harvests = _pick_distinct("harvests", harvest_slots, last_ids.get("harvests", []))
    visible_contracts = _pick_distinct("item_quests", contract_slots, last_ids.get("item_quests", []))
    _emit_refresh(StringName("harvests"))
    _emit_refresh(StringName("item_quests"))

func _emit_refresh(kind: StringName) -> void:
    if typeof(Events) != TYPE_OBJECT:
        return
    var list: Array[Dictionary] = visible_harvests if kind == StringName("harvests") else visible_contracts
    var snapshot: Array[Dictionary] = []
    for entry in list:
        snapshot.append(entry.duplicate(true))
    Events.offers_refreshed.emit(kind, snapshot)

func _pick_distinct(kind: String, count: int, recent: Variant) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    if count <= 0:
        return results
    var exclude: Array[StringName] = []
    if typeof(recent) == TYPE_ARRAY:
        for entry in recent:
            exclude.append(StringName(String(entry)))
    for i in range(count):
        var offer: Dictionary = _pick_one(StringName(kind), exclude)
        if offer.is_empty():
            break
        results.append(offer)
        exclude.append(StringName(offer.get("id", StringName(""))))
    return results

func _pick_one(kind: StringName, exclude_ids: Array[StringName] = []) -> Dictionary:
    var pool: Array[Dictionary] = ConfigDB.offers_pool(kind)
    if pool.is_empty():
        return {}
    var weights: Dictionary = ConfigDB.offers_weights(kind)
    var choices: Array = []
    var total_weight: float = 0.0
    for entry in pool:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id: StringName = entry.get("id", StringName(""))
        if id == StringName(""):
            continue
        if exclude_ids.has(id):
            continue
        var weight: float = float(weights.get(String(id), 1.0))
        if weight <= 0.0:
            continue
        choices.append({"entry": entry, "weight": weight})
        total_weight += weight
    if choices.is_empty() or total_weight <= 0.0:
        return {}
    var roll: float = _rng.randf_range(0.0, total_weight)
    var accum: float = 0.0
    for choice in choices:
        accum += float(choice.get("weight", 0.0))
        if roll <= accum:
            return (choice.get("entry") as Dictionary).duplicate(true)
    return (choices.back().get("entry") as Dictionary).duplicate(true)

func _record_last_id(kind: StringName, id: StringName) -> void:
    if id == StringName(""):
        return
    var key := String(kind)
    var history: Array = last_ids.get(key, [])
    history.append(id)
    var pool_size: int = ConfigDB.offers_pool(kind).size()
    var max_len: int = pool_size if pool_size > 0 else 4
    while history.size() > max_len:
        history.remove_at(0)
    last_ids[key] = history

func _current_ids(kind: StringName) -> Array[StringName]:
    var ids: Array[StringName] = []
    var list: Array[Dictionary] = visible_harvests if kind == StringName("harvests") else visible_contracts
    for entry in list:
        var id: StringName = entry.get("id", StringName(""))
        if id != StringName(""):
            ids.append(id)
    return ids

func _set_visible_list(kind: StringName, list: Array[Dictionary]) -> void:
    if kind == StringName("harvests"):
        visible_harvests = list
    else:
        visible_contracts = list
