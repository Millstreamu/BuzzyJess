extends Control
class_name BroodInsertRadialMenu

signal menu_closed()

@export var radius: float = 96.0
@export var button_size: Vector2 = Vector2(48, 48)
@export var animation_duration: float = 0.12
@export var padding: Vector2 = Vector2(120, 140)
@export var tiers: Array[StringName] = [
    StringName("Common"),
    StringName("Unique"),
    StringName("Rare")
]

var cell_id: int = -1
var center: Vector2 = Vector2.ZERO
var options: Array[StringName] = []
var angles: Array[float] = []
var buttons: Array[RadialOptionControl] = []
var counts: Array[int] = []
var affordable: Array[bool] = []
var selected_index: int = -1

var _is_open: bool = false
var _open_tween: Tween = null
var _close_tween: Tween = null

@onready var option_layer: Control = $OptionLayer
@onready var selection_ring: Control = $OptionLayer/SelectionRing

class RadialOptionControl extends Control:
    var label_text: String = ""
    var info_text: String = ""
    var affordable: bool = true
    var icon_size: Vector2 = Vector2.ZERO
    var base_color: Color = Color(0.89, 0.7, 0.21)
    var disabled_alpha: float = 0.5
    var _flash_tween: Tween = null

    func setup(label: StringName, info: String, size: Vector2, is_affordable: bool) -> void:
        label_text = String(label)
        info_text = info
        icon_size = size
        affordable = is_affordable
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        custom_minimum_size = Vector2(size.x, size.y + 36)
        size = custom_minimum_size
        queue_redraw()

    func update_state(info: String, is_affordable: bool) -> void:
        info_text = info
        affordable = is_affordable
        queue_redraw()

    func flash_unaffordable() -> void:
        if _flash_tween:
            _flash_tween.kill()
        modulate = Color.WHITE
        _flash_tween = create_tween()
        _flash_tween.tween_property(self, "modulate", Color(1.0, 0.4, 0.4), 0.05)
        _flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)

    func _draw() -> void:
        var icon_center: Vector2 = Vector2(icon_size.x * 0.5, icon_size.y * 0.5)
        var icon_radius: float = min(icon_size.x, icon_size.y) * 0.5
        var color: Color = base_color
        if not affordable:
            color.a = disabled_alpha
        draw_circle(icon_center, icon_radius, color)
        var font: Font = get_theme_default_font()
        if font:
            var font_size: int = max(1, get_theme_default_font_size())
            var width: float = max(size.x, icon_size.x)
            var label_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
            var label_pos: Vector2 = Vector2((width - label_size.x) * 0.5, icon_size.y + 16)
            draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
            var info_color: Color = Color(0.4, 0.9, 0.4) if affordable else Color(0.9, 0.3, 0.3)
            var info_size: Vector2 = font.get_string_size(info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
            var info_pos: Vector2 = Vector2((width - info_size.x) * 0.5, icon_size.y + 32)
            draw_string(font, info_pos, info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, info_color)

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    option_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    selection_ring.visible = false
    selection_ring.pivot_offset = selection_ring.size * 0.5
    set_process_unhandled_input(true)
    if typeof(Events) == TYPE_OBJECT:
        if not Events.inventory_changed.is_connected(_on_inventory_changed):
            Events.inventory_changed.connect(_on_inventory_changed)

func is_open() -> bool:
    return _is_open

func open_for_cell(p_cell_id: int, world_pos: Vector2) -> void:
    cell_id = p_cell_id
    center = _to_canvas_position(world_pos)
    _clamp_center()
    _prepare_options()
    option_layer.global_position = center
    option_layer.position = center
    _layout_buttons()
    _is_open = true
    visible = true
    option_layer.scale = Vector2(0.8, 0.8)
    option_layer.modulate = Color(1, 1, 1, 0)
    if options.size() > 0:
        selection_ring.visible = true
        selection_ring.modulate = Color(1, 1, 1, 1)
    _animate_in()

func close() -> void:
    if not _is_open:
        return
    _animate_out()

func _prepare_options() -> void:
    options.clear()
    angles.clear()
    buttons.clear()
    counts.clear()
    affordable.clear()
    for child: Node in option_layer.get_children():
        if child == selection_ring:
            continue
        child.queue_free()
    var inventory: Dictionary = InventorySystem.snapshot()
    for tier: StringName in tiers:
        options.append(tier)
        var item_id: StringName = StringName("Egg" + String(tier))
        var count: int = int(inventory.get(item_id, 0))
        counts.append(count)
        affordable.append(count > 0)
    var count_options: int = options.size()
    if count_options == 0:
        selected_index = -1
        _show_empty_placeholder()
        return
    var start_angle: float = -PI * 0.5
    for i: int in count_options:
        var angle: float = start_angle + float(i) * TAU / float(count_options)
        angles.append(angle)
    selected_index = clamp(selected_index, 0, count_options - 1)
    if selected_index < 0:
        selected_index = 0

func _show_empty_placeholder() -> void:
    selection_ring.visible = false
    var label: Label = Label.new()
    label.text = "No eggs"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(200, 40)
    label.position = -label.custom_minimum_size * 0.5
    option_layer.add_child(label)

func _layout_buttons() -> void:
    if options.is_empty():
        return
    buttons.clear()
    for i: int in options.size():
        var btn: RadialOptionControl = RadialOptionControl.new()
        var count_text: String = "x%d" % counts[i]
        var can_use: bool = affordable[i]
        btn.setup(options[i], count_text, button_size, can_use)
        var offset: Vector2 = Vector2(radius, 0).rotated(angles[i]) - button_size * 0.5
        btn.position = offset
        option_layer.add_child(btn)
        buttons.append(btn)
    selected_index = clamp(selected_index, 0, options.size() - 1)
    _update_ring()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open:
        return
    if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_released("ui_right") or event.is_action_released("ui_left") or event.is_action_released("ui_up") or event.is_action_released("ui_down"):
        var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
        if dir.length_squared() > 0.0:
            _select_dir(dir)
            accept_event()
        return
    elif event.is_action_pressed("confirm"):
        _confirm()
        accept_event()
    elif event.is_action_pressed("cancel"):
        close()
        accept_event()

func _select_dir(dir: Vector2) -> void:
    if options.is_empty():
        return
    if dir.length_squared() == 0.0:
        return
    var dir_normalized: Vector2 = dir.normalized()
    var best_dot: float = -INF
    var idx: int = selected_index
    for i: int in options.size():
        var v: Vector2 = Vector2.RIGHT.rotated(angles[i])
        var d: float = v.normalized().dot(dir_normalized)
        if d > best_dot:
            best_dot = d
            idx = i
    if idx != selected_index:
        selected_index = idx
        _update_ring()

func _update_ring() -> void:
    if options.is_empty() or selected_index < 0 or selected_index >= angles.size():
        selection_ring.visible = false
        return
    var local_center: Vector2 = Vector2(radius, 0).rotated(angles[selected_index])
    selection_ring.visible = true
    selection_ring.scale = Vector2.ONE
    selection_ring.position = local_center - selection_ring.pivot_offset
    selection_ring.queue_redraw()

func _confirm() -> void:
    if cell_id == -1:
        close()
        return
    if options.is_empty() or selected_index < 0 or selected_index >= options.size():
        return
    var tier: StringName = options[selected_index]
    if not EggSystem.insert_egg(cell_id, tier):
        _show_unaffordable_feedback(selected_index)
        return
    close()

func _show_unaffordable_feedback(idx: int) -> void:
    if idx >= 0 and idx < buttons.size():
        buttons[idx].flash_unaffordable()
    var tween: Tween = create_tween()
    tween.tween_property(selection_ring, "scale", selection_ring.scale * 1.15, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(selection_ring, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _animate_in() -> void:
    if _open_tween:
        _open_tween.kill()
    if _close_tween:
        _close_tween.kill()
    _open_tween = create_tween()
    _open_tween.tween_property(option_layer, "scale", Vector2.ONE, animation_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _open_tween.parallel().tween_property(option_layer, "modulate:a", 1.0, animation_duration)

func _animate_out() -> void:
    if _close_tween:
        _close_tween.kill()
    if _open_tween:
        _open_tween.kill()
    _close_tween = create_tween()
    _close_tween.tween_property(option_layer, "scale", Vector2(0.8, 0.8), animation_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    _close_tween.parallel().tween_property(option_layer, "modulate:a", 0.0, animation_duration)
    _close_tween.finished.connect(_on_close_finished)

func _on_close_finished() -> void:
    _is_open = false
    visible = false
    selection_ring.visible = false
    cell_id = -1
    menu_closed.emit()

func _to_canvas_position(world_pos: Vector2) -> Vector2:
    var viewport: Viewport = get_viewport()
    if viewport:
        var camera: Camera2D = viewport.get_camera_2d()
        if camera:
            return camera.unproject_position(world_pos)
    return world_pos

func _clamp_center() -> void:
    var rect: Rect2i = get_viewport_rect()
    var margin_x: float = max(padding.x, radius + button_size.x)
    var margin_y: float = max(padding.y, radius + button_size.y + 48.0)
    center.x = clamp(center.x, margin_x, rect.size.x - margin_x)
    center.y = clamp(center.y, margin_y, rect.size.y - margin_y)

func _refresh_counts() -> void:
    if options.is_empty():
        return
    var inventory: Dictionary = InventorySystem.snapshot()
    for i: int in options.size():
        var item_id: StringName = StringName("Egg" + String(options[i]))
        var count: int = int(inventory.get(item_id, 0))
        counts[i] = count
        var can_use: bool = count > 0
        affordable[i] = can_use
        if i < buttons.size():
            var count_text: String = "x%d" % count
            buttons[i].update_state(count_text, can_use)
    _update_ring()

func _on_inventory_changed(_snapshot: Dictionary) -> void:
    if _is_open:
        _refresh_counts()
