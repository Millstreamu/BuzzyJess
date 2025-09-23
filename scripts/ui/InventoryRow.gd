extends HBoxContainer
class_name InventoryRow

@onready var icon: TextureRect = $Icon
@onready var name_lbl: Label = $Info/Name
@onready var count_badge: Label = $Count

var _pending_icon: Texture2D = null
var _icon_pending: bool = false

var _pending_name: String = ""
var _name_pending: bool = false

var _pending_count: int = 0
var _count_pending: bool = true

func _ready() -> void:
    if _icon_pending:
        icon.texture = _pending_icon
        _icon_pending = false
    if _name_pending:
        name_lbl.text = _pending_name
        _name_pending = false
    if _count_pending:
        count_badge.text = _format_count(_pending_count)
    _count_pending = false

func set_id(id: StringName) -> void:
    set_meta("id", id)

func set_icon(tex: Texture2D) -> void:
    _pending_icon = tex
    if is_inside_tree():
        icon.texture = tex
        _icon_pending = false
    else:
        _icon_pending = true

func set_name_text(text: String) -> void:
    _pending_name = text
    if is_inside_tree():
        name_lbl.text = text
        _name_pending = false
    else:
        _name_pending = true

func set_count(amount: int) -> void:
    _pending_count = amount
    if is_inside_tree():
        count_badge.text = _format_count(amount)
        _count_pending = false
    else:
        _count_pending = true

func _format_count(amount: int) -> String:
    return "x%d" % max(amount, 0)
