extends Control
class_name ResourcesPanel

const SLIDE_IN_ANIM := StringName("slide_in")
const SLIDE_OUT_ANIM := StringName("slide_out")
const ROW_SCENE := preload("res://scenes/UI/ResourceRow.tscn")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var panel: PanelContainer = $Panel
@onready var list_vbox: VBoxContainer = $Panel/Layout/ListScroll/Rows
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
    if not Events.resources_changed.is_connected(_on_resources_changed):
        Events.resources_changed.connect(_on_resources_changed)
    _apply_panel_style()

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
    raise()
    if _rows.is_empty():
        _build_rows()
    _apply_snapshot()
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

func _apply_panel_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.11, 0.1, 0.12, 0.94)
    style.border_color = Color(1.0, 0.78, 0.32)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    footer_label.text = "Tab / Start = Close    Z = Cancel"

func _on_resources_changed(snap: Dictionary) -> void:
    _snapshot = snap.duplicate(true)
    if _is_open and not _closing:
        _apply_snapshot()

func _build_rows() -> void:
    _rows.clear()
    var ids: Array[StringName] = ConfigDB.get_resource_ids()
    for id in ids:
        var row: ResourceRow = ROW_SCENE.instantiate()
        row.set_meta("id", id)
        row.set_icon(IconDB.get_icon_for(id))
        row.set_name_text(ConfigDB.get_resource_display_name(id))
        list_vbox.add_child(row)
        _rows[id] = row

func _apply_snapshot() -> void:
    if _snapshot.is_empty():
        _snapshot = GameState.get_resources_snapshot()
    for id in _rows.keys():
        var row: ResourceRow = _rows[id]
        if not is_instance_valid(row):
            continue
        var entry: Dictionary = _snapshot.get(id, {})
        if entry.is_empty():
            entry = {
                "qty": 0,
                "cap": ConfigDB.get_resource_cap(id),
                "display_name": ConfigDB.get_resource_display_name(id)
            }
        row.set_name_text(String(entry.get("display_name", ConfigDB.get_resource_display_name(id))))
        row.set_values(int(entry.get("qty", 0)), int(entry.get("cap", 0)))

func _unhandled_input(event: InputEvent) -> void:
    if not _is_open or _closing:
        return
    if event.is_action_pressed("cancel") or event.is_action_pressed("resources_panel_toggle"):
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
