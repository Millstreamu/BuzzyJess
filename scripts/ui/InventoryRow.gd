extends MarginContainer
class_name InventoryRow

@onready var icon: TextureRect = $Panel/Icon
@onready var count_badge: Label = $Panel/Count

var _pending_icon: Texture2D = null
var _icon_pending: bool = false

var _pending_tooltip: String = ""
var _tooltip_pending: bool = false

var _pending_count: int = 0
var _count_pending: bool = true

func _ready() -> void:
    if _icon_pending:
        icon.texture = _pending_icon
        _icon_pending = false
    if _count_pending:
        _apply_count(_pending_count)
        _count_pending = false
    if _tooltip_pending:
        tooltip_text = _pending_tooltip
        _tooltip_pending = false

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
    _pending_tooltip = text
    if is_inside_tree():
        tooltip_text = text
        _tooltip_pending = false
    else:
        _tooltip_pending = true

func set_count(amount: int) -> void:
    _pending_count = amount
    if is_inside_tree():
        _apply_count(amount)
        _count_pending = false
    else:
        _count_pending = true

func _format_count(amount: int) -> String:
    return "%d" % max(amount, 0)

func _apply_count(amount: int) -> void:
    var display := max(amount, 0)
    count_badge.text = _format_count(display)
    count_badge.visible = display > 0
