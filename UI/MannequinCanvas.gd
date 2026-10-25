@tool
extends Control
class_name MannequinCanvas

## Native CanvasItem visual; the equipment socket Buttons are *scene nodes*,
## freely draggable and editable in Godot's scene editor.
func _draw() -> void:
    var mid: float = 176.0
    var edge := Color("#657583")
    var metal := Color("#354652")
    var accent := Color("#88bbc0")
    draw_rect(Rect2(Vector2.ZERO, size), Color("#121b27"), true)
    for y in range(0, int(size.y), 32):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color("#22323b"), 1.0)
    for x in range(0, int(size.x), 32):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#22323b"), 1.0)
    # Proportions echo a maintenance suit schematic, not an anatomical rendering.
    draw_circle(Vector2(mid, 64), 31.0, metal)
    draw_arc(Vector2(mid, 64), 31.0, 0.0, TAU, 40, edge, 3.0)
    draw_rect(Rect2(mid - 25, 99, 50, 115), metal, true)
    draw_rect(Rect2(mid - 25, 99, 50, 115), edge, false, 3.0)
    draw_line(Vector2(mid - 29, 112), Vector2(mid - 67, 194), edge, 20.0)
    draw_line(Vector2(mid + 29, 112), Vector2(mid + 67, 194), edge, 20.0)
    draw_line(Vector2(mid - 16, 213), Vector2(mid - 20, 340), edge, 24.0)
    draw_line(Vector2(mid + 16, 213), Vector2(mid + 20, 340), edge, 24.0)
    draw_rect(Rect2(mid - 34, 344, 29, 10), metal, true)
    draw_rect(Rect2(mid + 5, 344, 29, 10), metal, true)
    draw_circle(Vector2(mid, 144), 12.0, accent)
    draw_circle(Vector2(mid, 144), 6.0, metal)
    draw_line(Vector2(mid, 157), Vector2(mid, 200), accent, 2.0)
    draw_line(Vector2(mid - 10, 114), Vector2(mid + 10, 114), accent, 2.0)
    draw_string(get_theme_default_font(), Vector2(12, size.y - 13), "CYBERNETIC PLATFORM  /  MK-I", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#96a7b0"))
