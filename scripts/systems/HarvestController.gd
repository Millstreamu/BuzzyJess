extends Node

var _jobs: Dictionary = {}

func start_harvest(offer_id: StringName) -> bool:
    if offer_id == StringName(""):
        return false
    if typeof(OfferSystem) != TYPE_OBJECT:
        return false
    if not OfferSystem.is_visible(StringName("harvests"), offer_id):
        return false
    var offer: Dictionary = OfferSystem.get_offer(StringName("harvests"), offer_id)
    if offer.is_empty():
        return false
    if _jobs.has(offer_id):
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
    var delay_ratio: float = ConfigDB.offers_delay_ratio()
    var delay_seconds: float = float(ceil(delay_ratio * duration))
    var tick_seconds: float = max(ConfigDB.offers_tick_seconds(), 0.1)
    var outputs_value: Variant = offer.get("outputs", {})
    var outputs: Dictionary = {}
    if typeof(outputs_value) == TYPE_DICTIONARY:
        for key in outputs_value.keys():
            var id := StringName(String(key))
            outputs[id] = int(outputs_value.get(key, 0))
    var job_id: StringName = offer_id
    var job := {
        "id": job_id,
        "name": String(offer.get("name", String(job_id))),
        "base_required": base_required,
        "required": required,
        "start_time": now,
        "end_time": end_time,
        "duration": duration,
        "delay": delay_seconds,
        "elapsed": 0.0,
        "tick": tick_seconds,
        "outputs": outputs,
        "delivered": {},
        "accum": {},
        "bee_ids": reserved.duplicate()
    }
    for key in outputs.keys():
        job["delivered"][key] = 0
        job["accum"][key] = 0.0
    _jobs[job_id] = job
    _start_timer(job_id)
    if typeof(Events) == TYPE_OBJECT:
        Events.harvest_started.emit(job_id, end_time, required)
    return true

func is_active(offer_id: StringName) -> bool:
    return _jobs.has(offer_id)

func get_job_snapshot(offer_id: StringName) -> Dictionary:
    if not _jobs.has(offer_id):
        return {}
    return _snapshot(_jobs[offer_id])

func get_active_jobs() -> Array[Dictionary]:
    var list: Array[Dictionary] = []
    for job in _jobs.values():
        list.append(_snapshot(job))
    return list

func _start_timer(job_id: StringName) -> void:
    var job: Dictionary = _jobs.get(job_id, {})
    if job.is_empty():
        return
    var timer := Timer.new()
    timer.wait_time = float(job.get("tick", 1.0))
    timer.autostart = true
    timer.one_shot = false
    add_child(timer)
    timer.timeout.connect(func() -> void:
        _on_job_tick(job_id)
    )
    job["timer"] = timer
    _jobs[job_id] = job

func _on_job_tick(job_id: StringName) -> void:
    if not _jobs.has(job_id):
        return
    var job: Dictionary = _jobs[job_id]
    var tick_seconds: float = float(job.get("tick", 1.0))
    var elapsed: float = float(job.get("elapsed", 0.0)) + tick_seconds
    var duration: float = float(job.get("duration", 0.0))
    if elapsed > duration:
        elapsed = duration
    job["elapsed"] = elapsed
    var delay: float = float(job.get("delay", 0.0))
    var time_left: float = max(duration - elapsed, 0.0)
    if elapsed <= delay:
        if typeof(Events) == TYPE_OBJECT:
            Events.harvest_tick.emit(job_id, time_left, {})
        if elapsed >= duration:
            _finish_job(job_id, true)
        else:
            _jobs[job_id] = job
        return
    var work_time: float = max(duration - delay, tick_seconds)
    var outputs: Dictionary = job.get("outputs", {})
    var delivered: Dictionary = job.get("delivered", {})
    var accum: Dictionary = job.get("accum", {})
    var partials: Dictionary = {}
    var final_tick: bool = is_zero_approx(time_left)
    var assigned: Variant = job.get("bee_ids", [])
    var team_multiplier: float = 1.0
    if typeof(assigned) == TYPE_ARRAY:
        var bonus: float = 0.0
        for entry in assigned:
            var bee_id: int = int(entry)
            bonus += TraitsSystem.harvest_multiplier(bee_id) - 1.0
        team_multiplier = max(0.0, 1.0 + bonus)
    for key in outputs.keys():
        var resource_id: StringName = StringName(String(key))
        var total: int = int(outputs.get(key, 0))
        if total <= 0:
            continue
        var base_rate: float = float(total) / work_time
        var rate: float = base_rate * team_multiplier
        var prev_acc: float = float(accum.get(resource_id, 0.0))
        prev_acc += rate
        accum[resource_id] = prev_acc
        var delivered_prev: int = int(delivered.get(resource_id, 0))
        var should_have: int = int(floor(prev_acc))
        var give: int = should_have - delivered_prev
        if final_tick:
            give = total - delivered_prev
        if give <= 0:
            continue
        var space_left: int = GameState.space_left_for(resource_id)
        var can_give: int = give if space_left < 0 else min(give, space_left)
        if can_give > 0:
            GameState.add_resource(resource_id, can_give)
            delivered_prev += can_give
            delivered[resource_id] = delivered_prev
            partials[resource_id] = can_give
        if final_tick and can_give < give:
            push_warning("Harvest %s could not deliver %d %s due to storage limits" % [job.get("name", job_id), give - can_give, String(resource_id)])
    job["delivered"] = delivered
    job["accum"] = accum
    _jobs[job_id] = job
    if typeof(Events) == TYPE_OBJECT:
        Events.harvest_tick.emit(job_id, time_left, partials)
    if elapsed >= duration:
        _finish_job(job_id, true)

func _finish_job(job_id: StringName, success: bool) -> void:
    if not _jobs.has(job_id):
        return
    var job: Dictionary = _jobs[job_id]
    var timer: Timer = job.get("timer", null)
    if timer:
        timer.stop()
        timer.queue_free()
    var bees_value: Variant = job.get("bee_ids", [])
    GameState.free_gatherers(bees_value)
    _jobs.erase(job_id)
    if typeof(Events) == TYPE_OBJECT:
        Events.harvest_completed.emit(job_id, success)
    if success:
        OfferSystem.refill_one(StringName("harvests"), job_id)
        UIFx.show_toast("Harvest complete: %s" % String(job.get("name", job_id)))

func _snapshot(job: Dictionary) -> Dictionary:
    var snap: Dictionary = {}
    snap["id"] = job.get("id")
    snap["name"] = job.get("name", "")
    snap["start_time"] = job.get("start_time", 0.0)
    snap["end_time"] = job.get("end_time", 0.0)
    snap["duration"] = job.get("duration", 0.0)
    snap["delay"] = job.get("delay", 0.0)
    snap["elapsed"] = job.get("elapsed", 0.0)
    snap["outputs"] = job.get("outputs", {}).duplicate(true)
    snap["delivered"] = job.get("delivered", {}).duplicate(true)
    snap["required"] = job.get("required", 0)
    return snap

func apply_boost(effect: Dictionary) -> bool:
    if effect.is_empty():
        return false
    var mode: String = String(effect.get("mode", ""))
    match mode:
        "replenish_pct":
            var value_var: Variant = effect.get("value", 0.0)
            var pct: float = 0.0
            if typeof(value_var) == TYPE_FLOAT or typeof(value_var) == TYPE_INT:
                pct = float(value_var)
            if pct <= 0.0:
                return false
            var applied: bool = false
            for key in _jobs.keys():
                var job: Dictionary = _jobs[key]
                var outputs_value: Variant = job.get("outputs", {})
                if typeof(outputs_value) != TYPE_DICTIONARY:
                    continue
                var outputs: Dictionary = outputs_value.duplicate(true)
                var accum_value: Variant = job.get("accum", {})
                var accum: Dictionary = accum_value.duplicate(true) if typeof(accum_value) == TYPE_DICTIONARY else {}
                var updated: bool = false
                for res_key in outputs.keys():
                    var current_value: Variant = outputs.get(res_key, 0)
                    var current_total: float = 0.0
                    if typeof(current_value) == TYPE_FLOAT or typeof(current_value) == TYPE_INT:
                        current_total = float(current_value)
                    if current_total <= 0.0:
                        continue
                    var new_total_float: float = current_total * (1.0 + pct)
                    var new_total: int = int(round(new_total_float))
                    if new_total <= int(round(current_total)):
                        new_total = int(round(current_total)) + 1
                    outputs[res_key] = new_total
                    if not accum.is_empty():
                        var acc_value: Variant = accum.get(res_key, 0.0)
                        var prev_acc: float = 0.0
                        if typeof(acc_value) == TYPE_FLOAT or typeof(acc_value) == TYPE_INT:
                            prev_acc = float(acc_value)
                        if current_total > 0.0:
                            var ratio: float = float(new_total) / max(current_total, 0.0001)
                            accum[res_key] = prev_acc * ratio
                    updated = true
                if updated:
                    job["outputs"] = outputs
                    if not accum.is_empty():
                        job["accum"] = accum
                    _jobs[key] = job
                    applied = true
            return applied
        _:
            return false
