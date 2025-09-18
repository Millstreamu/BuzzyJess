extends PanelContainer
class_name ResourceRow

@onready var icon: TextureRect = $HBox/Icon
@onready var name_lbl: Label = $HBox/Info/Name
@onready var qty_lbl: Label = $HBox/Qty
@onready var bar_bg: ColorRect = $HBox/Info/Bar/Bg
@onready var bar_fg: ColorRect = $HBox/Info/Bar/Fg

var _pending_pct: float = -1.0

func _ready() -> void:
    _apply_style()
    set_process(false)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and _pending_pct >= 0.0:
        _update_bar_fill(_pending_pct)

func set_icon(tex: Texture2D) -> void:
    icon.texture = tex
    icon.visible = tex != null

func set_name_text(t: String) -> void:
    name_lbl.text = t

func set_values(q: int, c: int) -> void:
    qty_lbl.text = "%d/%d" % [q, c]
    var pct := 0.0
    if c > 0:
        pct = clamp(float(q) / float(c), 0.0, 1.0)
    _pending_pct = pct
    _update_bar_fill(pct)
    if c > 0 and q >= c:
        qty_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
    else:
        qty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))

func _apply_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.18, 0.16, 0.2, 0.92)
    style.set_corner_radius_all(16)
    style.set_border_width_all(1)
    style.border_color = Color(1.0, 0.75, 0.32, 0.6)
    add_theme_stylebox_override("panel", style)
    bar_bg.color = Color(0.08, 0.08, 0.1, 0.85)
    bar_fg.color = Color(1.0, 0.72, 0.28, 0.9)
    bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar_fg.visible = false

func _update_bar_fill(pct: float) -> void:
    if bar_bg == null or bar_fg == null:
        return
    var size_x := bar_bg.get_size().x
    if size_x <= 0:
        return
    bar_fg.size = Vector2(size_x * pct, bar_fg.size.y if bar_fg.size.y > 0 else bar_bg.size.y)
    bar_fg.visible = pct > 0.0
