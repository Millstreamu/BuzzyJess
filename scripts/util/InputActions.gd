# -----------------------------------------------------------------------------
# File: scripts/util/InputActions.gd
# Purpose: Centralized constants for common input action names
# Depends: Godot InputMap configuration
# Notes: Use to avoid typos when checking for actions in UI scripts
# -----------------------------------------------------------------------------

## InputActions
## Provides shared StringName constants for mapped input actions.
extends RefCounted
class_name InputActions

const CONFIRM := StringName("confirm")
const CANCEL := StringName("cancel")
const UI_UP := StringName("ui_up")
const UI_DOWN := StringName("ui_down")
const UI_LEFT := StringName("ui_left")
const UI_RIGHT := StringName("ui_right")
const INVENTORY_PANEL_TOGGLE := StringName("inventory_panel_toggle")
const ABILITIES_PANEL_TOGGLE := StringName("abilities_panel_toggle")
const RESOURCES_PANEL_TOGGLE := StringName("resources_panel_toggle")
const GATHER_PANEL_TOGGLE := StringName("gather_panel_toggle")
