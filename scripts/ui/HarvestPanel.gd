extends Control
class_name HarvestPanel

signal panel_closed()

const SLIDE_IN_ANIMATION := StringName("slide_in")
const SLIDE_OUT_ANIMATION := StringName("slide_out")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var header_label: Label = $Panel/Layout/Header
@onready var list_container: VBoxContainer = $Panel/Layout/ListScroll/VBox
@onready var footer_label: Label = $Panel/Layout/Footer/Hint

var _offers: Array[Dictionary] = Array[Dictionary]()
var _selected: int = 0
var _is_open: bool = false
var _closing: bool = false

func _ready() -> void:
    visible = false
    set_process_unhandled_input(true)
    if anim and not anim.animation_finished.is_connected(_on_animation_finished):
        anim.animation_finished.connect(_on_animation_finished)
    _apply_panel_style()
    _connect_events()
    if header_label:
        header_label.text = "Harvest Fields"
    if footer_label:
        footer_label.text = "Space = Start    Z = Close"

func open() -> void:
    _offers = ConfigDB.get_harvest_offers()
    _selected = 0
    _closing = false
    _is_open = true
    visible = true
    _rebuild_rows()
    if not _play_animation(SLIDE_IN_ANIMATION):
        position.x = 0

func close() -> void:
    if not _is_open or _closing:
        return
    _closing = true
    if not _play_animation(SLIDE_OUT_ANIMATION):
        _finalize_close()

func is_open() -> bool:
    return _is_open

func _apply_panel_style() -> void:
    if panel == null:
        return
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.11, 0.15, 0.96)
    style.border_color = Color(1.0, 0.78, 0.38)
    style.set_corner_radius_all(18)
    style.set_border_width_all(2)
    panel.add_theme_stylebox_override("panel", style)

func _connect_events() -> void:
    if typeof(Events) != TYPE_OBJECT:
        return
    if not Events.resources_changed.is_connected(_on_resources_changed):
        Events.resources_changed.connect(_on_resources_changed)
    if not Events.gatherer_bees_available_changed.is_connected(_on_bees_available_changed):
        Events.gatherer_bees_available_changed.connect(_on_bees_available_changed)
    if not Events.harvest_started.is_connected(_on_harvest_started):
        Events.harvest_started.connect(_on_harvest_started)
    if not Events.harvest_completed.is_connected(_on_harvest_completed):
        Events.harvest_completed.connect(_on_harvest_completed)
    if not Events.queen_selected.is_connected(_on_queen_selected):
        Events.queen_selected.connect(_on_queen_selected)

func _on_resources_changed(_snapshot: Dictionary) -> void:
    _refresh_if_open()

func _on_bees_available_changed(_count: int) -> void:
    _refresh_if_open()

func _on_harvest_started(_id: StringName, _end_time: float, _bees: int) -> void:
    _refresh_if_open()

func _on_harvest_completed(_id: StringName, _success: bool) -> void:
    _refresh_if_open()

func _on_queen_selected(_queen_id: StringName, _modifiers: Dictionary) -> void:
    _refresh_if_open()

func _refresh_if_open() -> void:
    if not _is_open:
        return
    _offers = ConfigDB.get_harvest_offers()
    if _offers.is_empty():
        _selected = 0
    else:
        _selected = clamp(_selected, 0, _offers.size() - 1)
    _rebuild_rows()

func _rebuild_rows() -> void:
    for child in list_container.get_children():
        child.queue_free()
    if _offers.is_empty():
        list_container.add_child(_make_message_label("No harvests available"))
        return
    _selected = clamp(_selected, 0, _offers.size() - 1)
    var available_bees: int = GameState.get_free_gatherers()
    for i in _offers.size():
        var offer: Dictionary = _offers[i]
        var base_required: int = int(offer.get("required_bees", 0))
        var required_bees: int = GameState.get_harvest_bee_requirement(base_required)
        var has_bees: bool = available_bees >= required_bees
        var cost_value: Variant = offer.get("cost", {})
        var cost: Dictionary = {}
        if typeof(cost_value) == TYPE_DICTIONARY:
            cost = cost_value
        var has_cost: bool = GameState.can_spend(cost)
        var row: Control = _make_row(offer, i == _selected, has_bees, has_cost, required_bees)
        list_container.add_child(row)

func _make_row(offer: Dictionary, selected: bool, has_bees: bool, has_cost: bool, required_bees: int) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(440, 84)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.2, 0.18, 0.24, 0.95)
    style.set_corner_radius_all(16)
    style.set_border_width_all(2 if selected else 1)
    style.border_color = Color(1.0, 0.76, 0.32) if selected else Color(0.5, 0.48, 0.6)
    card.add_theme_stylebox_override("panel", style)
    if not (has_bees and has_cost):
        card.modulate = Color(1, 1, 1, 0.65)

    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 16)
    row.alignment = BoxContainer.ALIGNMENT_CENTER

    var icon_rect := TextureRect.new()
    icon_rect.custom_minimum_size = Vector2(48, 48)
    icon_rect.texture = _get_offer_icon(offer)
    icon_rect.modulate = Color(1, 1, 1, 0.95) if icon_rect.texture != null else Color(0.8, 0.8, 0.8, 0.65)
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon_rect)

    var text_box := VBoxContainer.new()
    text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.add_theme_constant_override("separation", 6)

    var name_label := Label.new()
    name_label.text = String(offer.get("name", "Harvest"))
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(name_label)

    var info_label := Label.new()
    info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var duration_seconds: int = int(round(float(offer.get("duration_seconds", 0.0))))
    info_label.text = "Gatherers: %d    Time: %ds" % [required_bees, duration_seconds]
    info_label.modulate = Color(1, 1, 1, 0.8)
    text_box.add_child(info_label)

    row.add_child(text_box)

    var pill_box := VBoxContainer.new()
    pill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pill_box.alignment = BoxContainer.ALIGNMENT_END
    pill_box.add_theme_constant_override("separation", 6)

    var cost_text := _format_cost_text(offer.get("cost", {}))
    var cost_pill := _make_pill("Cost: %s" % cost_text, Color(0.32, 0.29, 0.4, 0.95))
    if not has_cost:
        var label := cost_pill.get_child(0)
        if label is Label:
            label.modulate = Color(1.0, 0.5, 0.5, 1.0)
    pill_box.add_child(cost_pill)

    var yield_text := _format_yield_text(offer.get("outputs", {}))
    var yield_pill := _make_pill("Yield: %s" % yield_text, Color(0.28, 0.45, 0.32, 0.95))
    pill_box.add_child(yield_pill)

    row.add_child(pill_box)
    card.add_child(row)
    return card

func _make_pill(text: String, bg_color: Color) -> PanelContainer:
    var pill := PanelContainer.new()
    pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = bg_color
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = Color(1, 1, 1, 0.45)
    pill.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(180, 28)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pill.add_child(label)
    return pill

func _make_message_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(420, 72)
    label.modulate = Color(1, 1, 1, 0.85)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _format_cost_text(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "None"
    var dict: Dictionary = value
    if dict.is_empty():
        return "None"
    var keys: Array = []
    for key in dict.keys():
        keys.append(String(key))
    keys.sort()
    var parts: Array[String] = Array[String]()
    for key_string in keys:
        var amount: int = int(dict.get(StringName(key_string), dict.get(key_string, 0)))
        var short_name: String = ConfigDB.get_resource_short_name(StringName(key_string))
        parts.append("%d %s" % [amount, short_name])
    return " ".join(parts)

func _format_yield_text(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "None"
    var dict: Dictionary = value
    if dict.is_empty():
        return "None"
    var keys: Array = []
    for key in dict.keys():
        keys.append(String(key))
    keys.sort()
    var parts: Array[String] = Array[String]()
    for key_string in keys:
        var amount: int = int(dict.get(StringName(key_string), dict.get(key_string, 0)))
        var short_name: String = ConfigDB.get_resource_short_name(StringName(key_string))
        parts.append("+%d %s" % [amount, short_name])
    return " ".join(parts)

func _get_offer_icon(offer: Dictionary) -> Texture2D:
    var outputs_value: Variant = offer.get("outputs", {})
    if typeof(outputs_value) == TYPE_DICTIONARY:
        for key in outputs_value.keys():
            return IconDB.get_icon_for(StringName(String(key)))
    var cost_value: Variant = offer.get("cost", {})
    if typeof(cost_value) == TYPE_DICTIONARY:
        for key in cost_value.keys():
            return IconDB.get_icon_for(StringName(String(key)))
    return null

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("ui_down"):
        _move_selection(1)
        accept_event()
    elif event.is_action_pressed("ui_up"):
        _move_selection(-1)
        accept_event()
    elif event.is_action_pressed("confirm"):
        _confirm_selection()
        accept_event()
    elif event.is_action_pressed("cancel") or event.is_action_pressed("gather_panel_toggle"):
        close()
        accept_event()

func _move_selection(delta: int) -> void:
    if _offers.is_empty():
        return
    var count: int = _offers.size()
    _selected = (_selected + delta + count) % count
    _rebuild_rows()

func _confirm_selection() -> void:
    if _offers.is_empty():
        UIFx.flash_deny()
        return
    _selected = clamp(_selected, 0, _offers.size() - 1)
    var offer: Dictionary = _offers[_selected]
    var cost_value: Variant = offer.get("cost", {})
    var cost: Dictionary = {}
    if typeof(cost_value) == TYPE_DICTIONARY:
        cost = cost_value
    var required_bees: int = GameState.get_harvest_bee_requirement(int(offer.get("required_bees", 0)))
    if GameState.get_free_gatherers() < required_bees:
        UIFx.flash_deny()
        return
    if not GameState.can_spend(cost):
        UIFx.flash_deny()
        return
    if HarvestController.start_harvest(offer):
        var name: String = String(offer.get("name", "Harvest"))
        var required: int = required_bees
        var duration: int = int(round(float(offer.get("duration_seconds", 0.0))))
        UIFx.show_toast("Started: %s (%d gatherers, %ds)" % [name, required, duration])
        close()
    else:
        UIFx.flash_deny()

func _on_animation_finished(anim_name: StringName) -> void:
    if anim_name == SLIDE_OUT_ANIMATION:
        _finalize_close()
    elif anim_name == SLIDE_IN_ANIMATION:
        position.x = 0

func _play_animation(name: StringName) -> bool:
    if anim and anim.has_animation(name):
        anim.play(name)
        return true
    return false

func _finalize_close() -> void:
    var was_open := _is_open
    visible = false
    _is_open = false
    _closing = false
    if was_open:
        panel_closed.emit()
