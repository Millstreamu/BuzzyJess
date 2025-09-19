extends Node

const RESOURCE_COLORS := {
    "Honey": Color(0.98, 0.78, 0.24),
    "Comb": Color(0.95, 0.64, 0.27),
    "Pollen": Color(0.98, 0.86, 0.38),
    "NectarCommon": Color(0.79, 0.52, 0.91),
    "PetalRed": Color(0.92, 0.32, 0.42),
    "Egg": Color(0.94, 0.94, 0.82)
}

var _icon_cache: Dictionary = {}

func get_icon_for(resource_id: StringName) -> Texture2D:
    var key := String(resource_id)
    if _icon_cache.has(key):
        return _icon_cache[key]
    var color: Color = RESOURCE_COLORS.get(key, _color_from_string(key))
    var tex := _make_circle_icon(color)
    _icon_cache[key] = tex
    return tex

func _make_circle_icon(color: Color) -> Texture2D:
    var size := 48
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var center := Vector2(size, size) * 0.5
    var radius := float(size) * 0.45
    for y in size:
        for x in size:
            var pos := Vector2(float(x) + 0.5, float(y) + 0.5)
            if pos.distance_to(center) <= radius:
                image.set_pixel(x, y, color)
    return ImageTexture.create_from_image(image)

func _color_from_string(value: String) -> Color:
    var hash: int = abs(value.hash())
    var r := float((hash >> 16) & 0xFF) / 255.0
    var g := float((hash >> 8) & 0xFF) / 255.0
    var b := float(hash & 0xFF) / 255.0
    return Color(r, g, b, 1.0)
