extends Node

signal cell_built(cell_id: int, cell_type: StringName)
signal resources_changed(snapshot: Dictionary)
signal build_menu_opened(cell_id: int)
signal build_menu_closed()
signal build_failed(cell_id: int)
