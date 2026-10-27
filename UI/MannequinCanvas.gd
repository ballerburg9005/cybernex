@tool
extends Control
class_name MannequinCanvas

## Drawn with CanvasItem (not a noise placeholder or a physics body).
## Every socket is still an individually editable Button in the Godot scene.
func _draw() -> void:
    var mid: float = 225.0
    var dark: Color = Color("#111b28")
    var grid_color: Color = Color("#213748")
    var chassis: Color = Color("#334653")
    var piping: Color = Color("#729caa")
    var bright: Color = Color("#b0e5e1")
    draw_rect(Rect2(Vector2.ZERO, size), dark, true)
    for x in range(0, int(size.x), 24):
        draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
    for y in range(0, int(size.y), 24):
        draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
    # The original suit art is scaled into the 330-pixel sidebar; sockets
    # remain independent Godot controls over the illustration.
    var scale_factor: float = minf(size.x / 450.0, size.y / 430.0)
    draw_set_transform(Vector2((size.x - 450.0 * scale_factor) * 0.5,
        (size.y - 430.0 * scale_factor) * 0.5), 0.0,
        Vector2.ONE * scale_factor)
    # Eight slot leads converge on matching anatomical/system mounts.
    var left: float = 126.0
    var right: float = 450.0 - 126.0
    var leads: Array = [
        [Vector2(left, 51), Vector2(mid - 32, 64)],
        [Vector2(right, 51), Vector2(mid + 12, 61)],
        [Vector2(left, 157), Vector2(mid - 65, 171)],
        [Vector2(right, 157), Vector2(mid + 32, 148)],
        [Vector2(left, 263), Vector2(mid - 23, 335)],
        [Vector2(right, 263), Vector2(mid + 67, 178)],
        [Vector2(left, 379), Vector2(mid - 62, 231)],
        [Vector2(right, 379), Vector2(mid + 62, 231)]
    ]
    for lead in leads:
        var a: Vector2 = lead[0]
        var b: Vector2 = lead[1]
        var elbow: Vector2 = Vector2(lerpf(a.x, b.x, 0.5), a.y)
        draw_line(a, elbow, piping.darkened(0.4), 2.0)
        draw_line(elbow, b, piping.darkened(0.4), 2.0)
        draw_circle(b, 3.5, bright)
    # Maintenance-suit mannequin: layered armor plates, joint bearings and
    # glowing telemetry elements leave the actual body visible between sockets.
    draw_line(Vector2(mid - 30, 129), Vector2(mid - 73, 242), piping, 19.0)
    draw_line(Vector2(mid + 30, 129), Vector2(mid + 73, 242), piping, 19.0)
    draw_line(Vector2(mid - 73, 242), Vector2(mid - 64, 261), bright.darkened(0.35), 13.0)
    draw_line(Vector2(mid + 73, 242), Vector2(mid + 64, 261), bright.darkened(0.35), 13.0)
    draw_line(Vector2(mid - 20, 244), Vector2(mid - 28, 392), piping, 28.0)
    draw_line(Vector2(mid + 20, 244), Vector2(mid + 28, 392), piping, 28.0)
    draw_rect(Rect2(mid - 48, 397, 40, 13), chassis, true)
    draw_rect(Rect2(mid + 8, 397, 40, 13), chassis, true)
    draw_rect(Rect2(mid - 46, 114, 92, 115), chassis, true)
    draw_rect(Rect2(mid - 46, 114, 92, 115), bright.darkened(0.4), false, 2.0)
    draw_line(Vector2(mid - 32, 159), Vector2(mid + 32, 159), piping, 2.0)
    draw_circle(Vector2(mid, 168), 17.0, piping)
    draw_circle(Vector2(mid, 168), 11.0, dark)
    draw_circle(Vector2(mid, 168), 5.0, bright)
    draw_rect(Rect2(mid - 35, 230, 70, 19), piping.darkened(0.25), true)
    draw_line(Vector2(mid, 185), Vector2(mid, 227), bright, 2.0)
    draw_circle(Vector2(mid, 72), 32.0, chassis)
    draw_arc(Vector2(mid, 72), 32.0, 0.0, TAU, 40, piping, 3.0)
    draw_rect(Rect2(mid - 27, 67, 54, 16), dark, true)
    draw_line(Vector2(mid - 22, 74), Vector2(mid + 22, 74), bright, 2.0)
    for y in [139.0, 198.0, 283.0, 345.0]:
        draw_line(Vector2(mid - 7, y), Vector2(mid + 7, y), bright.darkened(0.4), 2.0)
    draw_string(get_theme_default_font(), Vector2(mid - 62, 418.0),
        "SUIT PLATFORM MK-I", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, bright)

    draw_set_transform(Vector2.ZERO)
