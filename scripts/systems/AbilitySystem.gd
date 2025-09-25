extends Node

var _list: Array[Dictionary] = []

func _ready() -> void:
    _list.clear()

func list() -> Array[Dictionary]:
    return _list.duplicate(true)

func max_size() -> int:
    return int(ConfigDB.abilities_max_list())

func at_capacity() -> bool:
    var max_count: int = max_size()
    if max_count <= 0:
        return false
    return _list.size() >= max_count

func add_random_from_pool(exclude_ids: Array = []) -> StringName:
    if at_capacity():
        return StringName("")
    var excludes: Array = []
    for entry in _list:
        var id_string: String = String(entry.get("id", ""))
        if id_string.is_empty():
            continue
        excludes.append(StringName(id_string))
    for value in exclude_ids:
        var exclude_string: String = String(value)
        if exclude_string.is_empty():
            continue
        excludes.append(StringName(exclude_string))
    var picked: Dictionary = ConfigDB.abilities_pick_random(excludes)
    if picked.is_empty():
        return StringName("")
    _list.append(picked)
    var ability_id: StringName = StringName(String(picked.get("id", "")))
    if ability_id != StringName(""):
        if typeof(Events) == TYPE_OBJECT:
            Events.ability_added.emit(ability_id)
    return ability_id

func remove(id: StringName) -> void:
    if id == StringName(""):
        return
    for i in range(_list.size() - 1, -1, -1):
        var entry: Dictionary = _list[i]
        if StringName(String(entry.get("id", ""))) == id:
            _list.remove_at(i)
            if typeof(Events) == TYPE_OBJECT:
                Events.ability_removed.emit(id)
            return

func can_pay(ability: Dictionary) -> bool:
    if ability.is_empty():
        return false
    var cost_value: Variant = ability.get("cost", {})
    var resources_cost: Dictionary = {}
    var items_cost: Dictionary = {}
    if typeof(cost_value) == TYPE_DICTIONARY:
        var resources_value: Variant = cost_value.get("resources", {})
        if typeof(resources_value) == TYPE_DICTIONARY:
            for key in resources_value.keys():
                var amount_value: Variant = resources_value.get(key, 0)
                var amount: int = 0
                if typeof(amount_value) == TYPE_FLOAT or typeof(amount_value) == TYPE_INT:
                    amount = max(int(round(float(amount_value))), 0)
                if amount <= 0:
                    continue
                var res_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
                resources_cost[res_id] = amount
        var items_value: Variant = cost_value.get("items", {})
        if typeof(items_value) == TYPE_DICTIONARY:
            for key in items_value.keys():
                var qty_value: Variant = items_value.get(key, 0)
                var qty: int = 0
                if typeof(qty_value) == TYPE_FLOAT or typeof(qty_value) == TYPE_INT:
                    qty = max(int(round(float(qty_value))), 0)
                if qty <= 0:
                    continue
                var item_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
                items_cost[item_id] = qty
    if not GameState.can_spend(resources_cost):
        return false
    if not InventorySystem.has_all(items_cost):
        return false
    return true

func pay(ability: Dictionary) -> bool:
    if ability.is_empty():
        return false
    var cost_value: Variant = ability.get("cost", {})
    if typeof(cost_value) != TYPE_DICTIONARY or cost_value.is_empty():
        return true
    var resources_cost: Dictionary = {}
    var items_cost: Dictionary = {}
    var resources_value: Variant = cost_value.get("resources", {})
    if typeof(resources_value) == TYPE_DICTIONARY:
        for key in resources_value.keys():
            var amount_value: Variant = resources_value.get(key, 0)
            var amount: int = 0
            if typeof(amount_value) == TYPE_FLOAT or typeof(amount_value) == TYPE_INT:
                amount = max(int(round(float(amount_value))), 0)
            if amount <= 0:
                continue
            var res_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
            resources_cost[res_id] = amount
    var items_value: Variant = cost_value.get("items", {})
    if typeof(items_value) == TYPE_DICTIONARY:
        for key in items_value.keys():
            var qty_value: Variant = items_value.get(key, 0)
            var qty: int = 0
            if typeof(qty_value) == TYPE_FLOAT or typeof(qty_value) == TYPE_INT:
                qty = max(int(round(float(qty_value))), 0)
            if qty <= 0:
                continue
            var item_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
            items_cost[item_id] = qty
    if not GameState.can_spend(resources_cost):
        return false
    if not InventorySystem.has_all(items_cost):
        return false
    var spent_resources := false
    if not resources_cost.is_empty():
        if not GameState.spend(resources_cost):
            return false
        spent_resources = true
    for item_id in items_cost.keys():
        if not InventorySystem.remove_item(item_id, int(items_cost[item_id])):
            return false
    if spent_resources and typeof(Events) == TYPE_OBJECT:
        Events.resources_changed.emit(GameState.get_resources_snapshot())
    return true

func activate(id: StringName) -> bool:
    var ability: Dictionary = _find(id)
    if ability.is_empty():
        if typeof(Events) == TYPE_OBJECT:
            Events.ability_activated.emit(id, false)
        return false
    if not pay(ability):
        if typeof(Events) == TYPE_OBJECT:
            Events.ability_activated.emit(id, false)
        return false
    var success: bool = _apply_effect(ability.get("effect", {}))
    if success:
        remove(id)
    if typeof(Events) == TYPE_OBJECT:
        Events.ability_activated.emit(id, success)
    return success

func _find(id: StringName) -> Dictionary:
    if id == StringName(""):
        return {}
    for entry in _list:
        if StringName(String(entry.get("id", ""))) == id:
            return entry.duplicate(true)
    return {}

func _apply_effect(effect: Variant) -> bool:
    if typeof(effect) != TYPE_DICTIONARY:
        return false
    var type_string: String = String(effect.get("type", ""))
    match type_string:
        "buff":
            var target: StringName = StringName(String(effect.get("target", "")))
            if target == StringName(""):
                return false
            var mult_value: Variant = effect.get("mult", 1.0)
            var mult: float = 1.0
            if typeof(mult_value) == TYPE_FLOAT or typeof(mult_value) == TYPE_INT:
                mult = max(float(mult_value), 0.0)
            var duration_value: Variant = effect.get("duration", 0.0)
            var duration: float = 0.0
            if typeof(duration_value) == TYPE_FLOAT or typeof(duration_value) == TYPE_INT:
                duration = max(float(duration_value), 0.0)
            BuffsSystem.apply_temporary_buff(target, mult, duration)
            return true
        "spawn_bee":
            var rarity: StringName = StringName(String(effect.get("rarity", "Common")))
            var trait_count: int = ConfigDB.eggs_get_traits_per_rarity(rarity)
            var traits: Array[StringName] = TraitsSystem.generate_for_rarity(rarity, trait_count)
            GameState.add_bee({
                "rarity": rarity,
                "traits": traits
            })
            UIFx.show_toast("+1 %s Bee" % String(rarity))
            return true
        "harvest_boost":
            return HarvestController.apply_boost(effect)
        _:
            return false
