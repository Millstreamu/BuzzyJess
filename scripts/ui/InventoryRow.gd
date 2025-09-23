extends HBoxContainer
class_name InventoryRow

@onready var icon: TextureRect = $Icon
@onready var name_lbl: Label = $Info/Name
@onready var count_badge: Label = $Count

func set_id(id: StringName) -> void:
    set_meta("id", id)

func set_icon(tex: Texture2D) -> void:
    icon.texture = tex

func set_name_text(text: String) -> void:
    name_lbl.text = text

func set_count(amount: int) -> void:
    count_badge.text = "x%d" % max(amount, 0)
