extends PanelContainer
class_name AbilityRow

signal activated(id: StringName)

@onready var icon_rect: TextureRect = $HBox/Icon
@onready var name_label: Label = $HBox/Info/Name
@onready var desc_label: Label = $HBox/Info/Desc
@onready var cost_label: Label = $HBox/Info/Cost
@onready var activate_button: Button = $HBox/Activate

var data: Dictionary = {}

func _ready() -> void:
    activate_button.pressed.connect(_on_activate_pressed)
    _apply_style()

func setup(ability: Dictionary) -> void:
    data = ability.duplicate(true)
    var id_string: String = String(ability.get("id", ""))
    var name: String = String(ability.get("name", id_string.capitalize()))
    name_label.text = name
    desc_label.text = String(ability.get("desc", ""))
    icon_rect.texture = IconDB.get_icon_for(StringName(id_string))
    cost_label.text = _format_cost()
    set_affordable(AbilitySystem.can_pay(data))

func set_affordable(can_afford: bool) -> void:
    activate_button.disabled = not can_afford
    cost_label.modulate = Color(0.86, 0.92, 0.82) if can_afford else Color(0.98, 0.64, 0.64)
    if can_afford:
        activate_button.tooltip_text = "Activate this ability"
    else:
        activate_button.tooltip_text = "Cannot afford"

func _on_activate_pressed() -> void:
    var id: StringName = StringName(String(data.get("id", "")))
    if id == StringName(""):
        UIFx.flash_deny()
        return
    activated.emit(id)

func _format_cost() -> String:
    if data.is_empty():
        return "Free"
    var cost_value: Variant = data.get("cost", {})
    if typeof(cost_value) != TYPE_DICTIONARY or cost_value.is_empty():
        return "Free"
    var parts: Array[String] = []
    var resources_value: Variant = cost_value.get("resources", {})
    if typeof(resources_value) == TYPE_DICTIONARY:
        for key in resources_value.keys():
            var amount_value: Variant = resources_value.get(key, 0)
            var amount: int = 0
            if typeof(amount_value) == TYPE_FLOAT or typeof(amount_value) == TYPE_INT:
                amount = int(round(float(amount_value)))
            if amount <= 0:
                continue
            var res_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
            var display_name: String = ConfigDB.get_resource_display_name(res_id)
            parts.append("%d %s" % [amount, display_name])
    var items_value: Variant = cost_value.get("items", {})
    if typeof(items_value) == TYPE_DICTIONARY:
        for key in items_value.keys():
            var qty_value: Variant = items_value.get(key, 0)
            var qty: int = 0
            if typeof(qty_value) == TYPE_FLOAT or typeof(qty_value) == TYPE_INT:
                qty = int(round(float(qty_value)))
            if qty <= 0:
                continue
            var item_id: StringName = key if typeof(key) == TYPE_STRING_NAME else StringName(String(key))
            var item_def: Dictionary = ConfigDB.get_item_def(item_id)
            var item_name: String = String(item_def.get("name", String(item_id)))
            parts.append("%d %s" % [qty, item_name])
    if parts.is_empty():
        return "Free"
    return "Cost: " + ", ".join(parts)

func _apply_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.13, 0.12, 0.15, 0.9)
    style.border_color = Color(0.52, 0.44, 0.68)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    add_theme_stylebox_override("panel", style)
