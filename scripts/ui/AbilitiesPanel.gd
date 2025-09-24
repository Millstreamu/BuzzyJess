extends Control
class_name AbilitiesPanel

const SLIDE_IN_ANIM := StringName("slide_in")
const SLIDE_OUT_ANIM := StringName("slide_out")
const ROW_SCENE := preload("res://scenes/UI/AbilityRow.tscn")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var layout: VBoxContainer = $Panel/Layout
@onready var header: Label = $Panel/Layout/Header
@onready var list_vbox: VBoxContainer = $Panel/Layout/ListScroll/Rows
@onready var hint: Label = $Panel/Layout/Footer/Hint

var _is_open: bool = false
var _closing: bool = false

func _ready() -> void:
    visible = false
    set_process_unhandled_input(true)
    if anim:
        anim.animation_finished.connect(_on_animation_finished)
    _apply_panel_style()
    if typeof(Events) == TYPE_OBJECT:
        if not Events.ability_added.is_connected(_on_ability_changed):
            Events.ability_added.connect(_on_ability_changed)
        if not Events.ability_removed.is_connected(_on_ability_changed):
            Events.ability_removed.connect(_on_ability_changed)
        if not Events.resources_changed.is_connected(_on_resources_changed):
            Events.resources_changed.connect(_on_resources_changed)
        if not Events.inventory_changed.is_connected(_on_inventory_changed):
            Events.inventory_changed.connect(_on_inventory_changed)

func toggle() -> void:
    if _is_open and not _closing:
        close()
    else:
        open()

func open() -> void:
    if _closing:
        return
    _is_open = true
    visible = true
    move_to_front()
    _rebuild()
    if anim and anim.has_animation(SLIDE_IN_ANIM):
        anim.play(SLIDE_IN_ANIM)
    else:
        position.x = 0

func close() -> void:
    if not _is_open or _closing:
        return
    _closing = true
    if anim and anim.has_animation(SLIDE_OUT_ANIM):
        anim.play(SLIDE_OUT_ANIM)
    else:
        _finalize_close()

func is_open() -> bool:
    return _is_open and not _closing

func _apply_panel_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.11, 0.1, 0.12, 0.94)
    style.border_color = Color(0.76, 0.58, 0.92)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    hint.text = "L / Start = Close    Z = Cancel"

func _rebuild(_id: Variant = null) -> void:
    _clear_rows()
    var abilities: Array[Dictionary] = AbilitySystem.list()
    header.text = "Abilities (%d/%d)" % [abilities.size(), AbilitySystem.max_size()]
    for data in abilities:
        var row: AbilityRow = ROW_SCENE.instantiate()
        list_vbox.add_child(row)
        row.setup(data)
        row.activated.connect(_on_row_activated)
    _refresh_affordability()

func _clear_rows() -> void:
    for child in list_vbox.get_children():
        child.queue_free()

func _refresh_affordability(_snapshot: Variant = null) -> void:
    for child in list_vbox.get_children():
        if not child is AbilityRow:
            continue
        var row: AbilityRow = child
        row.set_affordable(AbilitySystem.can_pay(row.data))

func _on_row_activated(ability_id: StringName) -> void:
    AbilitySystem.activate(ability_id)

func _on_ability_changed(_ability_id: StringName) -> void:
    header.text = "Abilities (%d/%d)" % [AbilitySystem.list().size(), AbilitySystem.max_size()]
    if _is_open and not _closing:
        _rebuild()

func _on_resources_changed(_snapshot: Dictionary) -> void:
    if not _is_open or _closing:
        return
    _refresh_affordability()

func _on_inventory_changed(_snapshot: Dictionary) -> void:
    if not _is_open or _closing:
        return
    _refresh_affordability()

func _on_animation_finished(name: StringName) -> void:
    if name == SLIDE_OUT_ANIM:
        _finalize_close()
    elif name == SLIDE_IN_ANIM:
        position.x = 0

func _finalize_close() -> void:
    visible = false
    _is_open = false
    _closing = false

func _unhandled_input(event: InputEvent) -> void:
    if not is_open():
        return
    if event.is_action_pressed("cancel") or event.is_action_pressed("abilities_panel_toggle"):
        close()
        accept_event()

