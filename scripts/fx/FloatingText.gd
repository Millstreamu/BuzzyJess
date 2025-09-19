extends Label

var _tween: Tween = null

func _ready() -> void:
    horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    modulate = Color(1, 1, 1, 1)

func setup(text_value: String, color: Color = Color.WHITE) -> void:
    text = text_value
    modulate = color
    add_theme_font_size_override("font_size", 16)
    if _tween:
        _tween.kill()
    _tween = create_tween()
    var start_position: Vector2 = global_position
    _tween.tween_property(self, "global_position:y", start_position.y - 24.0, 0.6)
    _tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
    _tween.finished.connect(Callable(self, "queue_free"))
