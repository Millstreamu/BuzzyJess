extends Control
class_name InventoryPanel

const SLIDE_IN_ANIM := StringName("slide_in")
const SLIDE_OUT_ANIM := StringName("slide_out")
const ROW_SCENE := preload("res://scenes/UI/InventoryRow.tscn")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var list_vbox: VBoxContainer = $Panel/Layout/ListScroll/VBox
@onready var footer_label: Label = $Panel/Layout/Footer/Hint

var _rows: Dictionary = {}
var _snapshot: Dictionary = {}
var _is_open: bool = false
var _closing: bool = false

func _ready() -> void:
    visible = false
    set_process_unhandled_input(true)
    if anim:
        anim.animation_finished.connect(_on_animation_finished)
    if not Events.inventory_changed.is_connected(_on_inventory_changed):
        Events.inventory_changed.connect(_on_inventory_changed)
    _apply_panel_style()
    _build_static_rows()
    _apply_snapshot(InventorySystem.snapshot())

func toggle() -> void:
    if _is_open and not _closing:
        _close()
    else:
        _open()

func is_open() -> bool:
    return _is_open and not _closing

func _open() -> void:
    if _closing:
        return
    _is_open = true
    visible = true
    move_to_front()
    _apply_snapshot(InventorySystem.snapshot())
    if anim and anim.has_animation(SLIDE_IN_ANIM):
        anim.play(SLIDE_IN_ANIM)
    else:
        position.x = 0

func _close() -> void:
    if not _is_open or _closing:
        return
    _closing = true
    if anim and anim.has_animation(SLIDE_OUT_ANIM):
        anim.play(SLIDE_OUT_ANIM)
    else:
        _finalize_close()

func _on_inventory_changed(snap: Dictionary) -> void:
    _snapshot = snap.duplicate(true)
    if _is_open and not _closing:
        _apply_snapshot(_snapshot)

func _build_static_rows() -> void:
    _rows.clear()
    for child in list_vbox.get_children():
        child.queue_free()
    var list := ConfigDB.get_items_list()
    for item in list:
        var id_value: Variant = item.get("id", "")
        if typeof(id_value) != TYPE_STRING and typeof(id_value) != TYPE_STRING_NAME:
            continue
        var id: StringName = StringName(String(id_value))
        var row: InventoryRow = ROW_SCENE.instantiate()
        row.set_id(id)
        var icon_path: String = String(item.get("icon", ""))
        var icon_texture: Texture2D = null
        if not icon_path.is_empty():
            var loaded := load(icon_path)
            if loaded is Texture2D:
                icon_texture = loaded
        if icon_texture == null:
            icon_texture = IconDB.get_icon_for(id)
        row.set_icon(icon_texture)
        row.set_name_text(String(item.get("name", String(id))))
        row.set_count(0)
        list_vbox.add_child(row)
        _rows[id] = row

func _apply_snapshot(snap: Dictionary) -> void:
    _snapshot = snap.duplicate(true)
    for id in _rows.keys():
        var row: InventoryRow = _rows[id]
        if not is_instance_valid(row):
            continue
        var count: int = int(snap.get(id, 0))
        row.set_count(count)
        row.modulate = Color(1, 1, 1, 1) if count > 0 else Color(1, 1, 1, 0.4)

func _apply_panel_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.11, 0.1, 0.12, 0.94)
    style.border_color = Color(0.5, 0.8, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    footer_label.text = "I / Start = Close    Z = Cancel"

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open or _closing:
        return
    if event.is_action_pressed("cancel") or event.is_action_pressed("inventory_panel_toggle"):
        _close()
        accept_event()

func _on_animation_finished(name: StringName) -> void:
    if name == SLIDE_OUT_ANIM:
        _finalize_close()
    elif name == SLIDE_IN_ANIM:
        position.x = 0

func _finalize_close() -> void:
    visible = false
    _is_open = false
    _closing = false
