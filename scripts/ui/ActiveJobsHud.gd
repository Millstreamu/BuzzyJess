extends Control
class_name ActiveJobsHud

@onready var list_container: VBoxContainer = $Panel/Layout/VBox

var _harvest_cards: Dictionary = {}
var _contract_cards: Dictionary = {}

func _ready() -> void:
    set_process(true)
    _apply_panel_style()
    _connect_events()
    _refresh_existing_jobs()
    _update_visibility()

func _process(_delta: float) -> void:
    _update_countdowns()

func _connect_events() -> void:
    if typeof(Events) != TYPE_OBJECT:
        return
    if not Events.harvest_started.is_connected(_on_harvest_started):
        Events.harvest_started.connect(_on_harvest_started)
    if not Events.harvest_tick.is_connected(_on_harvest_tick):
        Events.harvest_tick.connect(_on_harvest_tick)
    if not Events.harvest_completed.is_connected(_on_harvest_completed):
        Events.harvest_completed.connect(_on_harvest_completed)
    if not Events.contract_started.is_connected(_on_contract_started):
        Events.contract_started.connect(_on_contract_started)
    if not Events.contract_completed.is_connected(_on_contract_completed):
        Events.contract_completed.connect(_on_contract_completed)

func _refresh_existing_jobs() -> void:
    if typeof(HarvestController) == TYPE_OBJECT:
        for job in HarvestController.get_active_jobs():
            _ensure_harvest_card(job)
    if typeof(ContractController) == TYPE_OBJECT:
        for job in ContractController.get_active_contracts():
            _ensure_contract_card(job)

func _update_countdowns() -> void:
    var now: float = Time.get_unix_time_from_system()
    for data in _harvest_cards.values():
        var label: Label = data.get("countdown")
        if label:
            var end_time: float = float(data.get("end_time", now))
            label.text = _format_time_left(max(end_time - now, 0.0))
    for data in _contract_cards.values():
        var label: Label = data.get("countdown")
        if label:
            var end_time: float = float(data.get("end_time", now))
            label.text = _format_time_left(max(end_time - now, 0.0))

func _on_harvest_started(id: StringName, end_time: float, _bees: int) -> void:
    if typeof(HarvestController) != TYPE_OBJECT:
        return
    var job := HarvestController.get_job_snapshot(id)
    if job.is_empty():
        job = {
            "id": id,
            "name": String(id),
            "end_time": end_time,
            "outputs": {},
            "delivered": {}
        }
    _ensure_harvest_card(job)
    _update_visibility()

func _on_harvest_tick(id: StringName, _time_left: float, _partials: Dictionary) -> void:
    _update_harvest_card(id)

func _on_harvest_completed(id: StringName, _success: bool) -> void:
    _remove_harvest_card(id)
    _update_visibility()

func _on_contract_started(id: StringName, end_time: float, _bees: int) -> void:
    if typeof(ContractController) != TYPE_OBJECT:
        return
    var job := ContractController.get_job_snapshot(id)
    if job.is_empty():
        job = {
            "id": id,
            "name": String(id),
            "end_time": end_time,
            "reward": {}
        }
    _ensure_contract_card(job)
    _update_visibility()

func _on_contract_completed(id: StringName, _success: bool) -> void:
    _remove_contract_card(id)
    _update_visibility()

func _ensure_harvest_card(job: Dictionary) -> void:
    var job_id: StringName = job.get("id", StringName(""))
    if job_id == StringName(""):
        return
    if _harvest_cards.has(job_id):
        var data: Dictionary = _harvest_cards[job_id]
        data["end_time"] = float(job.get("end_time", Time.get_unix_time_from_system()))
        _harvest_cards[job_id] = data
        _update_harvest_card(job_id)
        return
    var card := _create_card()
    var title := card.get_node("VBox/Title") as Label
    var countdown := card.get_node("VBox/Countdown") as Label
    var bars_container := card.get_node("VBox/Bars") as VBoxContainer
    title.text = String(job.get("name", job_id))
    var end_time: float = float(job.get("end_time", Time.get_unix_time_from_system()))
    countdown.text = _format_time_left(max(end_time - Time.get_unix_time_from_system(), 0.0))
    var outputs: Dictionary = job.get("outputs", {})
    var bars: Dictionary = {}
    if typeof(outputs) == TYPE_DICTIONARY:
        for key in outputs.keys():
            var resource_id: StringName = StringName(String(key))
            var total: int = int(outputs.get(key, 0))
            if total <= 0:
                continue
            var bar_row := _create_progress_row(resource_id, total)
            bars_container.add_child(bar_row["node"])
            bars[resource_id] = bar_row
    _harvest_cards[job_id] = {
        "node": card,
        "countdown": countdown,
        "end_time": end_time,
        "bars": bars
    }
    list_container.add_child(card)
    _update_harvest_card(job_id)

func _ensure_contract_card(job: Dictionary) -> void:
    var job_id: StringName = job.get("id", StringName(""))
    if job_id == StringName(""):
        return
    if _contract_cards.has(job_id):
        var data: Dictionary = _contract_cards[job_id]
        data["end_time"] = float(job.get("end_time", Time.get_unix_time_from_system()))
        _contract_cards[job_id] = data
        return
    var card := _create_card()
    var title := card.get_node("VBox/Title") as Label
    var countdown := card.get_node("VBox/Countdown") as Label
    var bars_container := card.get_node("VBox/Bars") as VBoxContainer
    bars_container.visible = false
    title.text = String(job.get("name", job_id))
    var end_time: float = float(job.get("end_time", Time.get_unix_time_from_system()))
    countdown.text = _format_time_left(max(end_time - Time.get_unix_time_from_system(), 0.0))
    _contract_cards[job_id] = {
        "node": card,
        "countdown": countdown,
        "end_time": end_time
    }
    list_container.add_child(card)

func _update_harvest_card(job_id: StringName) -> void:
    if typeof(HarvestController) != TYPE_OBJECT:
        return
    if not _harvest_cards.has(job_id):
        return
    var snapshot := HarvestController.get_job_snapshot(job_id)
    if snapshot.is_empty():
        return
    var bars: Dictionary = _harvest_cards[job_id].get("bars", {})
    var outputs: Dictionary = snapshot.get("outputs", {})
    var delivered: Dictionary = snapshot.get("delivered", {})
    for key in bars.keys():
        var entry: Dictionary = bars[key]
        var bar: ProgressBar = entry.get("bar")
        var total: int = int(outputs.get(key, 0))
        var done: int = int(delivered.get(key, 0))
        if bar:
            bar.max_value = max(total, 1)
            bar.value = clamp(done, 0, int(bar.max_value))
        var value_label: Label = entry.get("value_label")
        if value_label:
            value_label.text = "%d / %d" % [done, total]

func _remove_harvest_card(job_id: StringName) -> void:
    if not _harvest_cards.has(job_id):
        return
    var data: Dictionary = _harvest_cards[job_id]
    var node: Control = data.get("node")
    if node:
        node.queue_free()
    _harvest_cards.erase(job_id)

func _remove_contract_card(job_id: StringName) -> void:
    if not _contract_cards.has(job_id):
        return
    var data: Dictionary = _contract_cards[job_id]
    var node: Control = data.get("node")
    if node:
        node.queue_free()
    _contract_cards.erase(job_id)

func _create_card() -> PanelContainer:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.custom_minimum_size = Vector2(260, 88)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.18, 0.16, 0.22, 0.9)
    style.border_color = Color(1.0, 0.78, 0.38)
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    card.add_theme_stylebox_override("panel", style)
    var vbox := VBoxContainer.new()
    vbox.name = "VBox"
    vbox.add_theme_constant_override("separation", 6)
    var title := Label.new()
    title.name = "Title"
    title.text = "Job"
    vbox.add_child(title)
    var countdown := Label.new()
    countdown.name = "Countdown"
    countdown.modulate = Color(1, 1, 1, 0.8)
    vbox.add_child(countdown)
    var bars := VBoxContainer.new()
    bars.name = "Bars"
    bars.add_theme_constant_override("separation", 4)
    vbox.add_child(bars)
    card.add_child(vbox)
    return card

func _create_progress_row(resource_id: StringName, total: int) -> Dictionary:
    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 6)
    var label := Label.new()
    label.text = ConfigDB.get_resource_short_name(resource_id)
    hbox.add_child(label)
    var progress := ProgressBar.new()
    progress.custom_minimum_size = Vector2(120, 12)
    progress.max_value = max(total, 1)
    progress.value = 0
    progress.show_percentage = false
    hbox.add_child(progress)
    var value_label := Label.new()
    value_label.text = "0 / %d" % total
    value_label.modulate = Color(1, 1, 1, 0.8)
    hbox.add_child(value_label)
    return {
        "node": hbox,
        "bar": progress,
        "value_label": value_label
    }

func _format_time_left(seconds: float) -> String:
    var total: int = int(round(seconds))
    var minutes: int = total / 60
    var secs: int = total % 60
    return "%02d:%02d" % [minutes, secs]

func _update_visibility() -> void:
    if list_container == null:
        return
    var has_any: bool = not _harvest_cards.is_empty() or not _contract_cards.is_empty()
    visible = has_any

func _apply_panel_style() -> void:
    var panel := $Panel
    if panel == null:
        return
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.09, 0.13, 0.85)
    style.border_color = Color(1.0, 0.78, 0.38)
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel", style)
