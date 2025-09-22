extends PanelContainer
class_name QueenCard

var queen_id: StringName = StringName("")

@onready var icon_panel: PanelContainer = $Layout/IconPanel
@onready var icon_label: Label = $Layout/IconPanel/IconLabel
@onready var title_label: Label = $Layout/TitleLabel
@onready var desc_label: Label = $Layout/DescLabel

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _apply_styles()

func setup(id: String, name: String, desc: String) -> void:
    queen_id = StringName(id)
    if title_label:
        title_label.text = name
    if desc_label:
        desc_label.text = desc
    if icon_label:
        icon_label.text = "♛"

func _apply_styles() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.97, 0.87, 0.45, 0.98)
    style.set_corner_radius_all(28)
    style.set_border_width_all(2)
    style.border_color = Color(0.12, 0.08, 0.03, 1.0)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 28
    style.content_margin_bottom = 28
    add_theme_stylebox_override("panel", style)

    if icon_panel:
        var icon_style := StyleBoxFlat.new()
        icon_style.bg_color = Color(1.0, 0.95, 0.72, 0.9)
        icon_style.set_corner_radius_all(20)
        icon_style.set_border_width_all(2)
        icon_style.border_color = Color(0.25, 0.18, 0.07, 1.0)
        icon_panel.add_theme_stylebox_override("panel", icon_style)
        icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if icon_label:
        icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        icon_label.add_theme_font_size_override("font_size", 64)
        icon_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.06, 1.0))

    if title_label:
        title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title_label.add_theme_font_size_override("font_size", 26)
        title_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02, 1.0))

    if desc_label:
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        desc_label.add_theme_color_override("font_color", Color(0.05, 0.04, 0.02, 1.0))
        desc_label.add_theme_font_size_override("font_size", 20)
