extends Node2D

const OUTSIDE := Color("070e18")
const FLOOR_A := Color("17232d")
const FLOOR_B := Color("1a2832")
const TILE_EDGE := Color("24343e")
const HULL := Color("0d1822")
const HULL_EDGE := Color("344958")
const CYAN := Color("55d9e8")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), OUTSIDE)

	# One 30 px grid covers the viewport, with an open floor inside the hull.
	for row in range(18):
		for column in range(32):
			var tile := Rect2(column * 30, row * 30, 30, 30)
			var is_hull := row == 0 or row == 17 or column == 0 or column == 31
			if is_hull:
				draw_rect(tile, HULL)
				draw_rect(tile, HULL_EDGE, false, 1.0)
			else:
				var tile_color: Color = FLOOR_A if (row + column) % 2 == 0 else FLOOR_B
				draw_rect(tile, tile_color)
				draw_rect(tile, TILE_EDGE, false, 1.0)

	# Integrated hull lighting and panel seams, with no freestanding props.
	draw_rect(Rect2(30, 30, 900, 4), Color("294654"))
	draw_rect(Rect2(30, 506, 900, 4), Color("294654"))
	draw_rect(Rect2(30, 30, 4, 480), Color("294654"))
	draw_rect(Rect2(926, 30, 4, 480), Color("294654"))
	for x in range(60, 930, 90):
		draw_rect(Rect2(x, 6, 36, 4), CYAN)
		draw_rect(Rect2(x, 530, 36, 3), Color("287c8b"))

	# A restrained white-blue glow follows only the room's inner wall edge.
	# Keep the glow fully inside the floor so wall sprites cannot cover its edge.
	var wall_outline := Rect2(34, 34, 892, 472)
	draw_rect(wall_outline, Color(0.72, 0.9, 1.0, 0.08), false, 7.0)
	draw_rect(wall_outline, Color(0.78, 0.92, 1.0, 0.25), false, 3.0)
	draw_rect(wall_outline, Color(0.88, 0.96, 1.0, 0.72), false, 1.0)
