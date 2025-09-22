extends Control
class_name QueenSelect

signal queen_confirmed(queen_id: StringName)
signal selection_closed()

const CARD_SCENE := preload("res://scenes/UI/QueenCard.tscn")
const SEAT_TYPE := StringName("QueenSeat")
const FRAME_MARGIN := 12.0

var _cards: Array = []
var _selected: int = 0
var _frame_tween: Tween
var _pulse_tween: Tween
var _closed_emitted: bool = false

@onready var selection_frame: Control = $SelectionFrame
@onready var cards_box: HBoxContainer = $HBoxContainer

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    set_process_unhandled_input(true)
    _populate_cards()
    _update_frame(true)
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, get_size()), Color(0, 0, 0, 0.75))

func _populate_cards() -> void:
    if cards_box == null:
        return
    for child in cards_box.get_children():
        child.queue_free()
    _cards.clear()
    var list: Array[Dictionary] = ConfigDB.get_queens()
    if list.is_empty():
        return
    var count: int = min(3, list.size())
    for i in count:
        var entry: Dictionary = list[i].duplicate(true)
        var card_instance: QueenCard = CARD_SCENE.instantiate() if CARD_SCENE != null else null
        if card_instance == null:
            continue
        card_instance.setup(String(entry.get("id", "")), String(entry.get("name", "")), String(entry.get("desc", "")))
        cards_box.add_child(card_instance)
        _cards.append({"node": card_instance, "data": entry})
    cards_box.add_theme_constant_override("separation", 32)
    cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
    if cards_box.get_child_count() == 0:
        selection_frame.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
        _move(1)
        _accept()
    elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
        _move(-1)
        _accept()
    elif event.is_action_pressed("confirm"):
        _confirm()
        _accept()
    elif event.is_action_pressed("cancel"):
        _accept()

func _accept() -> void:
    var viewport := get_viewport()
    if viewport:
        viewport.set_input_as_handled()

func _move(delta: int) -> void:
    if _cards.is_empty():
        return
    var previous: int = _selected
    _selected = clamp(_selected + delta, 0, _cards.size() - 1)
    if previous != _selected:
        _update_frame()

func _update_frame(force: bool = false) -> void:
    if selection_frame == null:
        return
    if _cards.is_empty():
        selection_frame.visible = false
        return
    var entry: Dictionary = _cards[_selected]
    var card: Control = entry.get("node", null)
    if card == null:
        return
    selection_frame.visible = true
    var rect: Rect2 = card.get_global_rect()
    var target_pos: Vector2 = rect.position - Vector2(FRAME_MARGIN, FRAME_MARGIN)
    var target_size: Vector2 = rect.size + Vector2(FRAME_MARGIN, FRAME_MARGIN) * 2.0
    if force:
        selection_frame.global_position = target_pos
        selection_frame.size = target_size
        selection_frame.pivot_offset = selection_frame.size * 0.5
        _start_pulse()
        return
    if _frame_tween:
        _frame_tween.kill()
    _frame_tween = create_tween()
    _frame_tween.tween_property(selection_frame, "global_position", target_pos, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _frame_tween.parallel().tween_property(selection_frame, "size", target_size, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _frame_tween.tween_callback(Callable(self, "_sync_frame_pivot"))
    _start_pulse()

func _sync_frame_pivot() -> void:
    if selection_frame:
        selection_frame.pivot_offset = selection_frame.size * 0.5

func _start_pulse() -> void:
    if selection_frame == null:
        return
    if _pulse_tween:
        _pulse_tween.kill()
    selection_frame.scale = Vector2.ONE
    selection_frame.pivot_offset = selection_frame.size * 0.5
    _pulse_tween = create_tween()
    _pulse_tween.tween_property(selection_frame, "scale", Vector2.ONE * 1.04, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _pulse_tween.tween_property(selection_frame, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _confirm() -> void:
    if _cards.is_empty():
        return
    _selected = clamp(_selected, 0, _cards.size() - 1)
    var entry: Dictionary = _cards[_selected]
    var data: Dictionary = entry.get("data", {})
    var id_value: Variant = data.get("id", "")
    var queen_id_value: String = String(id_value)
    if queen_id_value.is_empty():
        return
    var effects_value: Variant = data.get("effects", {})
    var effects: Dictionary = {}
    if typeof(effects_value) == TYPE_DICTIONARY:
        effects = effects_value.duplicate(true)
    GameState.queen_id = StringName(queen_id_value)
    GameState.apply_queen_effects(effects)
    _place_queen_in_center()
    queen_confirmed.emit(GameState.queen_id)
    hide()
    _closed_emitted = true
    selection_closed.emit()
    var tree := get_tree()
    if tree:
        tree.paused = false
    queue_free()

func _place_queen_in_center() -> void:
    var center_id: int = HiveSystem.get_center_cell_id()
    if center_id == -1:
        return
    HiveSystem.set_cell_type(center_id, SEAT_TYPE)

func _on_tree_exiting() -> void:
    if _frame_tween:
        _frame_tween.kill()
    if _pulse_tween:
        _pulse_tween.kill()
    if not _closed_emitted:
        selection_closed.emit()
