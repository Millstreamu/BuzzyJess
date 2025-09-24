extends Control
class_name OffersPanel

signal panel_closed()

const SLIDE_IN_ANIMATION := StringName("slide_in")
const SLIDE_OUT_ANIMATION := StringName("slide_out")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var header_label: Label = $Panel/Layout/Header
@onready var tab_container: TabContainer = $Panel/Layout/TabContainer
@onready var harvest_list: VBoxContainer = $Panel/Layout/TabContainer/Harvests/ListScroll/VBox
@onready var contract_list: VBoxContainer = $Panel/Layout/TabContainer/Contracts/ListScroll/VBox
@onready var footer_label: Label = $Panel/Layout/Footer/Hint

var _is_open: bool = false
var _closing: bool = false
var _harvest_buttons: Array[Button] = []
var _contract_buttons: Array[Button] = []
var _focus_indices: Dictionary = {}

func _ready() -> void:
    visible = false
    set_process_unhandled_input(true)
    _apply_panel_style()
    _connect_events()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if panel:
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _focus_indices = {0: 0, 1: 0}
    if anim and not anim.animation_finished.is_connected(_on_animation_finished):
        anim.animation_finished.connect(_on_animation_finished)
    if tab_container and not tab_container.tab_changed.is_connected(_on_tab_changed):
        tab_container.tab_changed.connect(_on_tab_changed)
    if header_label:
        header_label.text = "Harvests & Contracts"
    if footer_label:
        footer_label.text = "Space = Start    Z = Close"

func open() -> void:
    _is_open = true
    _closing = false
    visible = true
    if tab_container:
        tab_container.current_tab = 0
    _refresh_lists()
    if not _play_animation(SLIDE_IN_ANIMATION):
        position.x = 0
    _focus_current_tab()

func close() -> void:
    if not _is_open or _closing:
        return
    _closing = true
    if not _play_animation(SLIDE_OUT_ANIMATION):
        _finalize_close()

func is_open() -> bool:
    return _is_open

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("cancel"):
        close()
        accept_event()
    elif event.is_action_pressed("confirm"):
        if not _activate_focused_button():
            _try_start_current_tab()
        accept_event()
    elif event.is_action_pressed("ui_down"):
        _move_focus(1)
        accept_event()
    elif event.is_action_pressed("ui_up"):
        _move_focus(-1)
        accept_event()
    elif event.is_action_pressed("ui_right"):
        _change_tab(1)
        accept_event()
    elif event.is_action_pressed("ui_left"):
        _change_tab(-1)
        accept_event()

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
    if not Events.gatherer_bees_available_changed.is_connected(_on_bees_changed):
        Events.gatherer_bees_available_changed.connect(_on_bees_changed)
    if not Events.offers_refreshed.is_connected(_on_offers_refreshed):
        Events.offers_refreshed.connect(_on_offers_refreshed)
    if not Events.harvest_started.is_connected(_on_harvest_started):
        Events.harvest_started.connect(_on_harvest_started)
    if not Events.harvest_completed.is_connected(_on_harvest_completed):
        Events.harvest_completed.connect(_on_harvest_completed)
    if not Events.contract_started.is_connected(_on_contract_started):
        Events.contract_started.connect(_on_contract_started)
    if not Events.contract_completed.is_connected(_on_contract_completed):
        Events.contract_completed.connect(_on_contract_completed)

func _on_resources_changed(_snapshot: Dictionary) -> void:
    _refresh_if_open()

func _on_bees_changed(_count: int) -> void:
    _refresh_if_open()

func _on_offers_refreshed(_kind: StringName, _list: Array) -> void:
    _refresh_if_open()

func _on_harvest_started(_id: StringName, _end: float, _bees: int) -> void:
    _refresh_if_open()

func _on_harvest_completed(_id: StringName, _success: bool) -> void:
    _refresh_if_open()

func _on_contract_started(_id: StringName, _end: float, _bees: int) -> void:
    _refresh_if_open()

func _on_contract_completed(_id: StringName, _success: bool) -> void:
    _refresh_if_open()

func _refresh_if_open() -> void:
    if not _is_open:
        return
    _refresh_lists()

func _refresh_lists() -> void:
    _harvest_buttons.clear()
    _contract_buttons.clear()
    _populate_list(StringName("harvests"), harvest_list)
    _populate_list(StringName("item_quests"), contract_list)
    if _is_open:
        _focus_current_tab()

func _populate_list(kind: StringName, container: VBoxContainer) -> void:
    if container == null:
        return
    for child in container.get_children():
        child.queue_free()
    if typeof(OfferSystem) != TYPE_OBJECT:
        container.add_child(_make_message_label("Offers unavailable"))
        return
    var offers: Array[Dictionary] = OfferSystem.get_visible(kind)
    if offers.is_empty():
        container.add_child(_make_message_label("No offers available"))
        return
    var available_bees: int = GameState.get_free_gatherers()
    for offer in offers:
        var base_required: int = int(offer.get("required_bees", 0))
        var required: int = GameState.get_harvest_bee_requirement(base_required)
        var has_bees: bool = available_bees >= required
        var cost: Dictionary = {}
        var cost_value: Variant = offer.get("cost", {})
        if typeof(cost_value) == TYPE_DICTIONARY:
            cost = cost_value
        var has_cost: bool = GameState.can_spend(cost)
        if kind == StringName("harvests"):
            var row := _make_harvest_row(offer, required, has_bees, has_cost)
            container.add_child(row)
        else:
            var row := _make_contract_row(offer, required, has_bees, has_cost)
            container.add_child(row)

func _make_message_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.modulate = Color(1, 1, 1, 0.8)
    return label

func _make_harvest_row(offer: Dictionary, required_bees: int, has_bees: bool, has_cost: bool) -> Control:
    var row := _make_row_container()
    var content := _make_offer_content(offer, required_bees, has_bees, has_cost, true)
    row.add_child(content)
    return row

func _make_contract_row(offer: Dictionary, required_bees: int, has_bees: bool, has_cost: bool) -> Control:
    var row := _make_row_container()
    var content := _make_offer_content(offer, required_bees, has_bees, has_cost, false)
    row.add_child(content)
    return row

func _make_row_container() -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(460, 92)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.2, 0.18, 0.24, 0.95)
    style.set_corner_radius_all(16)
    style.set_border_width_all(1)
    style.border_color = Color(0.5, 0.48, 0.6)
    card.add_theme_stylebox_override("panel", style)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return card

func _make_offer_content(offer: Dictionary, required_bees: int, has_bees: bool, has_cost: bool, is_harvest: bool) -> Control:
    var container := HBoxContainer.new()
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.alignment = BoxContainer.ALIGNMENT_CENTER
    container.add_theme_constant_override("separation", 16)

    var icon_rect := TextureRect.new()
    icon_rect.custom_minimum_size = Vector2(48, 48)
    icon_rect.texture = _get_offer_icon(offer, is_harvest)
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_rect.modulate = Color(1, 1, 1, 0.95) if icon_rect.texture != null else Color(0.8, 0.8, 0.8, 0.65)
    container.add_child(icon_rect)

    var text_box := VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.add_theme_constant_override("separation", 6)

    var name_label := Label.new()
    name_label.text = String(offer.get("name", "Offer"))
    text_box.add_child(name_label)

    var info_label := Label.new()
    var duration: int = int(round(float(offer.get("duration_seconds", 0.0))))
    var type_label := "Harvest" if is_harvest else "Contract"
    info_label.text = "%s    Bees: %d    Time: %ds" % [type_label, required_bees, duration]
    info_label.modulate = Color(1, 1, 1, 0.8)
    text_box.add_child(info_label)

    container.add_child(text_box)

    var pill_box := VBoxContainer.new()
    pill_box.alignment = BoxContainer.ALIGNMENT_END
    pill_box.add_theme_constant_override("separation", 6)

    var cost_text := _format_resource_dict(offer.get("cost", {}))
    if is_harvest:
        var yield_text := _format_resource_dict(offer.get("outputs", {}))
        pill_box.add_child(_make_pill("Yield: %s" % (yield_text if not yield_text.is_empty() else "None"), Color(0.28, 0.45, 0.32, 0.95)))
        if not cost_text.is_empty():
            var cost_pill := _make_pill("Cost: %s" % cost_text, Color(0.32, 0.29, 0.4, 0.95))
            if not has_cost:
                _tint_label(cost_pill, Color(1.0, 0.5, 0.5, 1.0))
            pill_box.add_child(cost_pill)
    else:
        var cost_label := cost_text if not cost_text.is_empty() else "None"
        var cost_pill := _make_pill("Cost: %s" % cost_label, Color(0.32, 0.29, 0.4, 0.95))
        if not has_cost:
            _tint_label(cost_pill, Color(1.0, 0.5, 0.5, 1.0))
        pill_box.add_child(cost_pill)
        var reward_text := _format_reward_dict(offer.get("reward", {}))
        pill_box.add_child(_make_pill("Reward: %s" % (reward_text if not reward_text.is_empty() else "None"), Color(0.28, 0.45, 0.32, 0.95)))

    container.add_child(pill_box)

    var button := Button.new()
    button.text = "Start"
    button.disabled = not (has_bees and has_cost) or _is_offer_running(offer.get("id"), is_harvest)
    button.pressed.connect(func() -> void:
        if is_harvest:
            _attempt_start_harvest(offer)
        else:
            _attempt_start_contract(offer)
    )
    _register_offer_button(button, is_harvest)
    container.add_child(button)

    if button.disabled or not (has_bees and has_cost):
        container.modulate = Color(1, 1, 1, 0.7)

    return container

func _make_pill(text: String, bg_color: Color) -> PanelContainer:
    var pill := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = bg_color
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = Color(1, 1, 1, 0.45)
    pill.add_theme_stylebox_override("panel", style)
    var label := Label.new()
    label.text = text
    pill.add_child(label)
    return pill

func _tint_label(pill: PanelContainer, color: Color) -> void:
    if pill == null:
        return
    if pill.get_child_count() <= 0:
        return
    var label := pill.get_child(0)
    if label is Label:
        label.modulate = color

func _get_offer_icon(offer: Dictionary, is_harvest: bool) -> Texture2D:
    if typeof(IconDB) != TYPE_OBJECT:
        return null
    if is_harvest:
        var outputs_value: Variant = offer.get("outputs", {})
        if typeof(outputs_value) == TYPE_DICTIONARY:
            for key in outputs_value.keys():
                var amount: int = int(outputs_value.get(key, 0))
                if amount <= 0:
                    continue
                return IconDB.get_icon_for(StringName(String(key)))
    else:
        var reward_value: Variant = offer.get("reward", {})
        if typeof(reward_value) == TYPE_DICTIONARY:
            for key in reward_value.keys():
                return IconDB.get_icon_for(StringName(String(key)))
    return null

func _format_resource_dict(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return ""
    var parts: Array[String] = []
    for key in value.keys():
        var amount: int = int(value.get(key, 0))
        if amount <= 0:
            continue
        var id := StringName(String(key))
        var name := ConfigDB.get_resource_display_name(id)
        parts.append("%s x%d" % [name, amount])
    return ", ".join(parts)

func _format_reward_dict(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return ""
    var parts: Array[String] = []
    for key in value.keys():
        var amount: int = int(value.get(key, 0))
        if amount <= 0:
            continue
        var id := StringName(String(key))
        var item_def: Dictionary = ConfigDB.get_item_def(id)
        var name: String = String(item_def.get("name", String(id)))
        parts.append("%s x%d" % [name, amount])
    return ", ".join(parts)

func _is_offer_running(id_value: Variant, is_harvest: bool) -> bool:
    var offer_id: StringName = StringName(String(id_value))
    if offer_id == StringName(""):
        return false
    if is_harvest:
        return HarvestController.is_active(offer_id)
    return ContractController.is_active(offer_id)

func _attempt_start_harvest(offer: Dictionary) -> void:
    var offer_id: StringName = StringName(String(offer.get("id", "")))
    if offer_id == StringName(""):
        UIFx.flash_deny()
        return
    if HarvestController.start_harvest(offer_id):
        UIFx.show_toast("Harvest started: %s" % String(offer.get("name", "Harvest")))
        close()
    else:
        UIFx.flash_deny()

func _attempt_start_contract(offer: Dictionary) -> void:
    var offer_id: StringName = StringName(String(offer.get("id", "")))
    if offer_id == StringName(""):
        UIFx.flash_deny()
        return
    if ContractController.start_contract(offer_id):
        UIFx.show_toast("Contract started: %s" % String(offer.get("name", "Contract")))
        close()
    else:
        UIFx.flash_deny()

func _try_start_current_tab() -> void:
    if tab_container == null:
        return
    var index: int = tab_container.current_tab
    if index == 0:
        _start_first_available(harvest_list, true)
    else:
        _start_first_available(contract_list, false)

func _start_first_available(list_container: VBoxContainer, is_harvest: bool) -> void:
    if list_container == null:
        return
    for child in list_container.get_children():
        var row := child
        if row is PanelContainer and row.get_child_count() > 0:
            var content := row.get_child(0)
            if content is HBoxContainer:
                for grand in content.get_children():
                    if grand is Button and not grand.disabled:
                        grand.emit_signal("pressed")
                        return

func _register_offer_button(button: Button, is_harvest: bool) -> void:
    if button == null:
        return
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tab_index: int = 0 if is_harvest else 1
    if is_harvest:
        _harvest_buttons.append(button)
    else:
        _contract_buttons.append(button)
    button.focus_entered.connect(func() -> void:
        var buttons := _button_list_for(tab_index)
        var idx := buttons.find(button)
        if idx >= 0:
            _focus_indices[tab_index] = idx
    )

func _button_list_for(tab_index: int) -> Array[Button]:
    return _harvest_buttons if tab_index == 0 else _contract_buttons

func _focus_current_tab() -> void:
    if not _is_open or tab_container == null:
        return
    var tab_index: int = tab_container.current_tab
    var buttons := _button_list_for(tab_index)
    if buttons.is_empty():
        return
    var start_index: int = int(_focus_indices.get(tab_index, 0))
    _focus_from_index(tab_index, start_index)

func _move_focus(delta: int) -> void:
    if not _is_open or tab_container == null:
        return
    var tab_index: int = tab_container.current_tab
    var buttons := _button_list_for(tab_index)
    if buttons.is_empty():
        UIFx.flash_deny()
        return
    var index: int = int(_focus_indices.get(tab_index, 0))
    var count: int = buttons.size()
    for _i in range(count):
        index = wrapi(index + delta, 0, count)
        var button := buttons[index]
        if _can_focus_button(button):
            _focus_indices[tab_index] = index
            button.grab_focus()
            return
    UIFx.flash_deny()

func _activate_focused_button() -> bool:
    var button := _current_focus_button()
    if button == null:
        return false
    if button.disabled:
        UIFx.flash_deny()
        return false
    button.emit_signal("pressed")
    return true

func _current_focus_button() -> Button:
    if tab_container == null:
        return null
    var tab_index: int = tab_container.current_tab
    var buttons := _button_list_for(tab_index)
    if buttons.is_empty():
        return null
    var index: int = int(_focus_indices.get(tab_index, 0))
    if index < 0 or index >= buttons.size():
        return null
    var button := buttons[index]
    if button != null and button.is_inside_tree():
        return button
    return null

func _change_tab(delta: int) -> void:
    if tab_container == null:
        return
    var count: int = tab_container.get_tab_count()
    if count <= 1:
        UIFx.flash_deny()
        return
    var next: int = wrapi(tab_container.current_tab + delta, 0, count)
    if next == tab_container.current_tab:
        return
    tab_container.current_tab = next
    _focus_current_tab()

func _focus_from_index(tab_index: int, start_index: int) -> void:
    var buttons := _button_list_for(tab_index)
    if buttons.is_empty():
        return
    var count: int = buttons.size()
    for offset in range(count):
        var idx := wrapi(start_index + offset, 0, count)
        var button := buttons[idx]
        if _can_focus_button(button):
            _focus_indices[tab_index] = idx
            button.grab_focus()
            return

func _can_focus_button(button: Button) -> bool:
    return button != null and button.visible and not button.disabled

func _on_tab_changed(_tab: int) -> void:
    if _is_open:
        _focus_current_tab()

func _play_animation(name: StringName) -> bool:
    if anim == null or not anim.has_animation(name):
        return false
    anim.play(name)
    return true

func _on_animation_finished(animation_name: StringName) -> void:
    if animation_name == SLIDE_OUT_ANIMATION and _closing:
        _finalize_close()

func _finalize_close() -> void:
    visible = false
    _is_open = false
    _closing = false
    panel_closed.emit()
