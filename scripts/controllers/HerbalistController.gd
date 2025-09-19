extends Node
class_name HerbalistController

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")

@export var panel_path: NodePath

var panel: HerbalistPanel = null

func _ready() -> void:
    if panel_path != NodePath():
        panel = get_node_or_null(panel_path)
    if panel and not panel.panel_closed.is_connected(_on_panel_closed):
        panel.panel_closed.connect(_on_panel_closed)
    _connect_events()

func toggle_panel() -> void:
    if panel == null:
        return
    if panel.is_open():
        panel.close()
        return
    if not _has_herbalist_den():
        UIFx.flash_deny()
        UIFx.show_toast("Build a Herbalist Den to access Contracts")
        return
    panel.open()

func close_panel() -> void:
    if panel and panel.is_open():
        panel.close()

func is_panel_open() -> bool:
    return panel != null and panel.is_open()

func _on_panel_closed() -> void:
    pass

func _connect_events() -> void:
    if typeof(Events) != TYPE_OBJECT:
        return
    if not Events.herbalist_contract_completed.is_connected(_on_contract_completed):
        Events.herbalist_contract_completed.connect(_on_contract_completed)

func _on_contract_completed(contract_id: StringName, success: bool) -> void:
    if not success:
        return
    var contract: Dictionary = ConfigDB.get_herbalist_contract(contract_id)
    if contract.is_empty():
        return
    var name: String = String(contract.get("name", String(contract_id)))
    var reward_text: String = _format_reward(contract.get("reward", {}))
    if reward_text.is_empty():
        UIFx.show_toast("Completed: %s" % name)
    else:
        UIFx.show_toast("Completed: %s %s" % [name, reward_text])

func _format_reward(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return ""
    var dict: Dictionary = value
    if dict.is_empty():
        return ""
    var keys: Array = []
    for key in dict.keys():
        keys.append(String(key))
    keys.sort()
    var parts: Array[String] = []
    for key_string in keys:
        var amount: int = int(dict.get(StringName(key_string), dict.get(key_string, 0)))
        var short_name: String = ConfigDB.get_resource_short_name(StringName(key_string))
        parts.append("+%d %s" % [amount, short_name])
    return " ".join(parts)

func _has_herbalist_den() -> bool:
    var cells: Dictionary = HiveSystem.get_cells()
    for entry in cells.values():
        if String(entry.get("type", "")) == "HerbalistDen":
            return true
    return false

