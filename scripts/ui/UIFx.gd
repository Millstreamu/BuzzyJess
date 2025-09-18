extends Node
class_name UIFx

static func flash_deny() -> void:
    # Placeholder feedback hook for deny actions.
    if Engine.is_editor_hint():
        return
    # In lieu of a full VFX system, emit a simple debug message.
    print("[UIFx] deny flash")
