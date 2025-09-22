extends Node

const TICK_INTERVAL := 1.0

var _jobs: Dictionary = {}

func start_harvest(harvest: Dictionary) -> bool:
    if harvest.is_empty():
        return false
    var base_required_bees: int = int(harvest.get("required_bees", 0))
    var required_bees: int = GameState.get_harvest_bee_requirement(base_required_bees)
    if GameState.get_free_gatherers() < required_bees:
        return false
    var cost_value: Variant = harvest.get("cost", {})
    var cost: Dictionary = {}
    if typeof(cost_value) == TYPE_DICTIONARY:
        cost = cost_value
    if not GameState.can_spend(cost):
        return false
    var id_string: String = String(harvest.get("id", ""))
    if id_string.is_empty():
        id_string = "Harvest-%d" % Time.get_unix_time_from_system()
    var job_id: StringName = StringName(id_string)
    if _jobs.has(job_id):
        return false
    if not GameState.reserve_gatherers(required_bees):
        return false
    if not GameState.spend(cost):
        GameState.free_gatherers(required_bees)
        return false
    var name: String = String(harvest.get("name", id_string))
    var duration: float = max(float(harvest.get("duration_seconds", 0.0)), 0.0)
    var now: float = Time.get_unix_time_from_system()
    var end_time: float = now + duration
    var delay_seconds: int = int(ceil(0.05 * duration))
    var outputs_dict: Dictionary = {}
    var outputs_value: Variant = harvest.get("outputs", {})
    if typeof(outputs_value) == TYPE_DICTIONARY:
        for key in outputs_value.keys():
            var key_name: StringName = StringName(String(key))
            outputs_dict[key_name] = int(outputs_value.get(key, 0))
    var job := {
        "id": job_id,
        "name": name,
        "required_bees": required_bees,
        "base_required_bees": base_required_bees,
        "duration": duration,
        "end_time": end_time,
        "t_delay": delay_seconds,
        "t_elapsed": 0,
        "outputs": outputs_dict,
        "delivered": {},
        "acc": {},
        "field_world_pos": harvest.get("field_world_pos", Vector2.ZERO)
    }
    for key in outputs_dict.keys():
        job.delivered[key] = 0
        job.acc[key] = 0.0
    _jobs[job_id] = job
    _start_timer(job)
    Events.harvest_started.emit(job_id, end_time, required_bees)
    return true

func _start_timer(job: Dictionary) -> void:
    var timer := Timer.new()
    timer.wait_time = TICK_INTERVAL
    timer.autostart = true
    timer.one_shot = false
    add_child(timer)
    timer.timeout.connect(func() -> void:
        _on_harvest_tick(job)
    )
    job["timer"] = timer

func _on_harvest_tick(job: Dictionary) -> void:
    if job.is_empty():
        return
    job.t_elapsed = int(job.get("t_elapsed", 0)) + 1
    var duration: float = float(job.get("duration", 0.0))
    var delay: int = int(job.get("t_delay", 0))
    var elapsed: int = int(job.get("t_elapsed", 0))
    var time_left: float = max(duration - float(elapsed), 0.0)
    if elapsed <= delay:
        Events.harvest_tick.emit(job.get("id"), time_left, {})
        if float(elapsed) >= duration:
            _finish_harvest(job)
        return
    var work_time: float = max(duration - float(delay), 1.0)
    var outputs: Dictionary = job.get("outputs", {})
    var delivered: Dictionary = job.get("delivered", {})
    var acc: Dictionary = job.get("acc", {})
    var partials: Dictionary = {}
    var final_tick: bool = time_left <= 0.0
    for key in outputs.keys():
        var resource_id: StringName = key
        var total: int = int(outputs[key])
        if total <= 0:
            continue
        var rate: float = float(total) / work_time
        var prev_acc: float = float(acc.get(resource_id, 0.0))
        prev_acc += rate
        acc[resource_id] = prev_acc
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
        if can_give < give and final_tick:
            push_warning("Harvest %s could not deliver %d %s due to storage limits" % [String(job.get("name", "")), give - can_give, String(resource_id)])
    job["delivered"] = delivered
    job["acc"] = acc
    Events.harvest_tick.emit(job.get("id"), time_left, partials)
    if float(job.get("t_elapsed", 0)) >= duration:
        _finish_harvest(job)

func _finish_harvest(job: Dictionary) -> void:
    var job_id: StringName = job.get("id", StringName(""))
    var timer: Timer = job.get("timer", null)
    if timer:
        timer.stop()
        timer.queue_free()
    var required: int = int(job.get("required_bees", 0))
    GameState.free_gatherers(required)
    _jobs.erase(job_id)
    Events.harvest_completed.emit(job_id, true)
    UIFx.show_toast("Harvest complete: %s" % String(job.get("name", job_id)))
