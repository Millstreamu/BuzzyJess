extends Node
class_name GatheringController

const HiveSystem := preload("res://scripts/systems/HiveSystem.gd")

@export var panel_path: NodePath

var panel: HarvestPanel = null

func _ready() -> void:
    if panel_path != NodePath():
        panel = get_node_or_null(panel_path)
    if panel and not panel.panel_closed.is_connected(_on_panel_closed):
        panel.panel_closed.connect(_on_panel_closed)

func toggle_panel() -> void:
    if panel == null:
        return
    if panel.is_open():
        panel.close()
        return
    if not _has_gathering_hut():
        UIFx.flash_deny()
        UIFx.show_toast("Build a Gathering Hut to access Harvests")
        return
    panel.open()

func close_panel() -> void:
    if panel and panel.is_open():
        panel.close()

func is_panel_open() -> bool:
    return panel != null and panel.is_open()

func _on_panel_closed() -> void:
    pass

func _has_gathering_hut() -> bool:
    var cells: Dictionary = HiveSystem.get_cells()
    for entry in cells.values():
        if String(entry.get("type", "")) == "GatheringHut":
            return true
    return false
