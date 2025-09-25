extends Node

var _contracts: Dictionary = {}

func start_contract(offer_id: StringName) -> bool:
    if offer_id == StringName(""):
        return false
    if typeof(OfferSystem) != TYPE_OBJECT:
        return false
    if not OfferSystem.is_visible(StringName("item_quests"), offer_id):
        return false
    var offer: Dictionary = OfferSystem.get_offer(StringName("item_quests"), offer_id)
    if offer.is_empty():
        return false
    if _contracts.has(offer_id):
        return false
    var base_required: int = int(offer.get("required_bees", 0))
    var required: int = GameState.get_harvest_bee_requirement(base_required)
    if GameState.get_free_gatherers() < required:
        return false
    var cost_value: Variant = offer.get("cost", {})
    var cost: Dictionary = {}
    if typeof(cost_value) == TYPE_DICTIONARY:
        cost = cost_value
    if not GameState.can_spend(cost):
        return false
    var reserved: Array[int] = GameState.reserve_gatherers(required)
    if reserved.size() < required:
        GameState.free_gatherers(reserved)
        return false
    if not cost.is_empty() and not GameState.spend(cost):
        GameState.free_gatherers(reserved)
        return false
    var duration: float = max(float(offer.get("duration_seconds", 0.0)), 0.0)
    var now: float = Time.get_unix_time_from_system()
    var end_time: float = now + duration
    var reward_value: Variant = offer.get("reward", {})
    var reward: Dictionary = {}
    if typeof(reward_value) == TYPE_DICTIONARY:
        for key in reward_value.keys():
            var id := StringName(String(key))
            reward[id] = int(reward_value.get(key, 0))
    var job := {
        "id": offer_id,
        "name": String(offer.get("name", String(offer_id))),
        "required": required,
        "base_required": base_required,
        "start_time": now,
        "end_time": end_time,
        "duration": duration,
        "bee_ids": reserved.duplicate(),
        "reward": reward,
        "cost": cost.duplicate(true)
    }
    _contracts[offer_id] = job
    _start_timer(offer_id)
    if typeof(Events) == TYPE_OBJECT:
        Events.contract_started.emit(offer_id, end_time, required)
    return true

func is_active(offer_id: StringName) -> bool:
    return _contracts.has(offer_id)

func get_job_snapshot(offer_id: StringName) -> Dictionary:
    if not _contracts.has(offer_id):
        return {}
    return _snapshot(_contracts[offer_id])

func get_active_contracts() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for job in _contracts.values():
        list.append(_snapshot(job))
    return list

func _start_timer(offer_id: StringName) -> void:
    var job: Dictionary = _contracts.get(offer_id, {})
    if job.is_empty():
        return
    var duration: float = float(job.get("duration", 0.0))
    var timer := Timer.new()
    timer.wait_time = max(duration, 0.01)
    timer.autostart = true
    timer.one_shot = true
    add_child(timer)
    timer.timeout.connect(func() -> void:
        _finish_contract(offer_id, true)
    )
    job["timer"] = timer
    _contracts[offer_id] = job

func _finish_contract(offer_id: StringName, success: bool) -> void:
    if not _contracts.has(offer_id):
        return
    var job: Dictionary = _contracts[offer_id]
    var timer: Timer = job.get("timer", null)
    if timer:
        timer.stop()
        timer.queue_free()
    var bees_value: Variant = job.get("bee_ids", [])
    GameState.free_gatherers(bees_value)
    _contracts.erase(offer_id)
    if success:
        var reward: Dictionary = job.get("reward", {})
        for key in reward.keys():
            var amount: int = int(reward.get(key, 0))
            if amount <= 0:
                continue
            InventorySystem.add_item(StringName(String(key)), amount)
    if typeof(Events) == TYPE_OBJECT:
        Events.contract_completed.emit(offer_id, success)
    if success:
        OfferSystem.refill_one(StringName("item_quests"), offer_id)
        UIFx.show_toast("Contract complete: %s" % String(job.get("name", offer_id)))

func _snapshot(job: Dictionary) -> Dictionary:
    var snap: Dictionary = {}
    snap["id"] = job.get("id")
    snap["name"] = job.get("name", "")
    snap["start_time"] = job.get("start_time", 0.0)
    snap["end_time"] = job.get("end_time", 0.0)
    snap["duration"] = job.get("duration", 0.0)
    snap["reward"] = job.get("reward", {}).duplicate(true)
    snap["required"] = job.get("required", 0)
    return snap
