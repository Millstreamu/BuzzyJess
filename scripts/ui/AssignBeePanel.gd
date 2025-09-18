extends Control
class_name AssignBeePanel

signal assign_confirmed(cell_id: int, group_id: int, bee_id: int)
signal panel_closed()

var _cell_id: int = -1
var _group_id: int = -1
var _building_type: StringName = &""
var _rows: Array = []
var _selected: int = 0
var _can_assign: bool = true
var _is_open: bool = false
var _closing: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Layout/Title
@onready var list: VBoxContainer = $Panel/Layout/ListMargin/Scroll/BeeList

func _ready() -> void:
    visible = false
    set_process_unhandled_input(true)
    anim.animation_finished.connect(_on_animation_finished)
    _apply_panel_style()

func open(cell_id: int, group_id: int, building_type: StringName, rows: Array, can_assign: bool) -> void:
    _cell_id = cell_id
    _group_id = group_id
    _building_type = building_type
    _rows = rows
    _selected = 0
    _can_assign = can_assign
    _closing = false
    _is_open = true
    title_label.text = "Assign Bee – %s" % String(building_type)
    _rebuild_list()
    visible = true
    anim.play("slide_in")

func close() -> void:
    if _closing:
        return
    _closing = true
    anim.play("slide_out")

func is_open() -> bool:
    return _is_open

func _apply_panel_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.11, 0.1, 0.12, 0.92)
    style.border_color = Color(1.0, 0.77, 0.34)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)

func _rebuild_list() -> void:
    for child in list.get_children():
        child.queue_free()
    if not _can_assign:
        list.add_child(_make_message_label("No capacity"))
    if _rows.is_empty():
        list.add_child(_make_message_label("No available bees"))
        return
    _selected = clamp(_selected, 0, max(_rows.size() - 1, 0))
    for i in _rows.size():
        var data: Dictionary = _rows[i]
        var row: Control = _make_row(data.get("bee", {}), int(data.get("eff", 0)), i == _selected)
        if not _can_assign:
            row.modulate = Color(1, 1, 1, 0.5)
        list.add_child(row)

func _make_row(bee: Dictionary, eff: int, selected: bool) -> Control:
    var container := PanelContainer.new()
    container.custom_minimum_size = Vector2(360, 56)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.22, 0.2, 0.25, 0.9)
    style.set_corner_radius_all(14)
    style.set_border_width_all(2 if selected else 1)
    style.border_color = Color(1.0, 0.74, 0.32) if selected else Color(0.45, 0.45, 0.52)
    container.add_theme_stylebox_override("panel", style)
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 12)
    row.alignment = BoxContainer.ALIGNMENT_CENTER

    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(40, 40)
    icon.texture = bee.get("icon", null)
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.modulate = Color(1, 1, 1, 1) if icon.texture else Color(0.8, 0.8, 0.8, 0.6)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)

    var label := Label.new()
    label.text = bee.get("display_name", "Bee")
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(label)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)

    row.add_child(_make_badge(eff))

    container.add_child(row)
    return container

func _make_badge(efficiency: int) -> Control:
    var badge := PanelContainer.new()
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.28, 0.45, 0.28, 0.9) if efficiency >= 0 else Color(0.6, 0.28, 0.28, 0.9)
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = Color(1, 1, 1, 0.6)
    badge.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.custom_minimum_size = Vector2(48, 24)
    label.text = _format_efficiency(efficiency)
    badge.add_child(label)
    return badge

func _format_efficiency(efficiency: int) -> String:
    if efficiency > 0:
        return "+%d" % efficiency
    return str(efficiency)

func _make_message_label(text: String) -> Control:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(340, 48)
    label.modulate = Color(1, 1, 1, 0.85)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("ui_down"):
        _move(1)
        accept_event()
    elif event.is_action_pressed("ui_up"):
        _move(-1)
        accept_event()
    elif event.is_action_pressed("confirm"):
        _confirm()
        accept_event()
    elif event.is_action_pressed("cancel"):
        close()
        accept_event()

func _move(dir: int) -> void:
    if _rows.is_empty() or not _can_assign:
        return
    _selected = (_selected + dir + _rows.size()) % _rows.size()
    _rebuild_list()

func _confirm() -> void:
    if not _can_assign:
        UIFx.flash_deny()
        return
    if _rows.is_empty():
        UIFx.flash_deny()
        return
    _selected = clamp(_selected, 0, _rows.size() - 1)
    var data: Dictionary = _rows[_selected]
    var bee: Dictionary = data.get("bee", {})
    var bee_id: int = int(bee.get("id", -1))
    if bee_id == -1:
        UIFx.flash_deny()
        return
    assign_confirmed.emit(_cell_id, _group_id, bee_id)
    close()

func _on_animation_finished(anim_name: StringName) -> void:
    if anim_name == StringName("slide_out"):
        visible = false
        _is_open = false
        _closing = false
        panel_closed.emit()
    elif anim_name == StringName("slide_in"):
        position.x = 0
