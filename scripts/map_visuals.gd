extends Node2D

const OUTSIDE := Color("080f18")
const TILE_A := Color("202d38")
const TILE_B := Color("24323c")
const TILE_EDGE := Color("34424b")
const HULL := Color("111c26")
const ACCENT := Color("456170")
const CYAN := Color("3b9cab")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), OUTSIDE)
	for row in range(18):
		for column in range(32):
			var tile := Rect2(column * 30, row * 30, 30, 30)
			if row == 0 or row == 17 or column == 0 or column == 31:
				draw_rect(tile, HULL)
				draw_rect(tile, ACCENT, false, 1.0)
			else:
				var tile_color: Color = TILE_A if (row + column) % 2 == 0 else TILE_B
				draw_rect(tile, tile_color)
				draw_rect(tile, TILE_EDGE, false, 1.0)

	# Mark the open play area with subtle sector lines and corner beacons.
	draw_rect(Rect2(210, 120, 540, 300), Color(0.16, 0.30, 0.36, 0.22), false, 2.0)
	draw_line(Vector2(480, 120), Vector2(480, 420), Color(0.25, 0.43, 0.49, 0.25), 1.0)
	draw_line(Vector2(210, 270), Vector2(750, 270), Color(0.25, 0.43, 0.49, 0.25), 1.0)
	for beacon in [Vector2(72, 72), Vector2(888, 72), Vector2(72, 468), Vector2(888, 468)]:
		draw_rect(Rect2(beacon - Vector2(5, 5), Vector2(10, 10)), CYAN)
