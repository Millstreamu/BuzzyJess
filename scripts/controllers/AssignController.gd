extends Node
class_name AssignController

@export var panel_path: NodePath

var panel: AssignBeePanel = null
var _current_cell: int = -1

func _ready() -> void:
    if panel_path != NodePath():
        panel = get_node_or_null(panel_path)
    if panel:
        panel.assign_confirmed.connect(_on_assign_confirmed)
        panel.panel_closed.connect(_on_panel_closed)

func open_panel(cell_id: int) -> void:
    if panel == null:
        return
    var info: Dictionary = HiveSystem.get_building_info(cell_id)
    if info.is_empty():
        UIFx.flash_deny()
        return
    var cell_type: StringName = StringName(info.get("type", "Empty"))
    if cell_type == StringName("Empty") or cell_type == StringName("Brood"):
        UIFx.flash_deny()
        return
    var bees: Array = GameState.get_available_bees()
    var rows: Array = []
    for bee in bees:
        var eff: int = get_efficiency(bee, cell_type)
        rows.append({"bee": bee, "eff": eff})
    var capacity: int = int(info.get("capacity", 0))
    var assigned: Array = info.get("assigned", [])
    var can_assign: bool = assigned.size() < capacity and capacity > 0
    _current_cell = cell_id
    panel.open(cell_id, int(info.get("group_id", cell_id)), cell_type, rows, can_assign)

func get_efficiency(bee: Dictionary, building_type: StringName) -> int:
    return ConfigDB.get_efficiency(building_type)

func is_panel_open() -> bool:
    return panel != null and panel.is_open()

func _on_assign_confirmed(cell_id: int, group_id: int, bee_id: int) -> void:
    if not HiveSystem.has_capacity(group_id):
        UIFx.flash_deny()
        return
    var building_type: StringName = StringName(HiveSystem.get_cell_type(cell_id))
    var bee_data: Dictionary = GameState.get_bee_by_id(bee_id)
    var efficiency: int = get_efficiency(bee_data, building_type)
    GameState.assign_bee_to_building(bee_id, group_id)
    HiveSystem.assign_bee_to_group(group_id, bee_id, efficiency, GameState.get_bee_icon(bee_id))
    Events.assignment_changed.emit(cell_id, bee_id)
    Events.resources_changed.emit(GameState.get_resources_snapshot())
    _current_cell = -1

func _on_panel_closed() -> void:
    _current_cell = -1
