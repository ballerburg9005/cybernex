extends Control
## Four-band real-world resistor marking (10-ohm: brown, black, black, gold).
## 3px integer-aligned stripes overlay the original physical resistor glyph.
func _draw() -> void:
    var colors: Array[Color] = [
        Color("#794022"), Color("#161616"), Color("#161616"), Color("#bd9b30")
    ]
    for i in range(4):
        draw_rect(Rect2(9.0 + i * 8.0, 18.0, 3.0, 12.0), colors[i], true)
