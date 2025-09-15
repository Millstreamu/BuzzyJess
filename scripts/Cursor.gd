extends Node2D

@onready var line: Line2D = $Line2D

func _ready() -> void:
    var radius := 32.0 # half of 64
    var h := sqrt(3.0) * 0.5 * radius
    # Flat-top hex vertices (clockwise), centered at (0,0)
    var pts := PackedVector2Array([
        Vector2(+radius, 0),
        Vector2(+radius * 0.5, +h),
        Vector2(-radius * 0.5, +h),
        Vector2(-radius, 0),
        Vector2(-radius * 0.5, -h),
        Vector2(+radius * 0.5, -h),
    ])
    line.points = pts
    line.closed = true
    line.width = 3.0
    line.default_color = Color(1, 1, 1) # white
