extends Node2D

const GRID_WIDTH := 32
const GRID_HEIGHT := 18
const CELL_SIZE := 30
const MAX_SPLIT_DEPTH := 3
const START_REGION := Rect2i(1, 1, GRID_WIDTH - 2, GRID_HEIGHT - 2)

const VOID_COLOR := Color("080f18")
const FLOOR_A := Color("202d38")
const FLOOR_B := Color("24323c")
const FLOOR_EDGE := Color("34424b")
const WALL_COLOR := Color("101a23")
const WALL_TOP := Color("3b5665")
const WALL_SIDE := Color("182631")
const ACCENT := Color("49b9c8")

var _rng := RandomNumberGenerator.new()
var _grid: Array = []
var _seed_value := 0

@onready var player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	_rng.randomize()
	_seed_value = _rng.randi()
	_initialize_grid()
	var bsp_root := _partition(START_REGION, 0)
	var rooms := _carve_bsp(bsp_root)
	if not rooms.is_empty():
		player_spawn.position = _cell_center(_room_center(rooms[0]))
	_build_wall_collisions()
	queue_redraw()


func _initialize_grid() -> void:
	_grid.clear()
	for y in range(GRID_HEIGHT):
		var row: Array[bool] = []
		for _x in range(GRID_WIDTH):
			row.append(false)
		_grid.append(row)


func _partition(region: Rect2i, depth: int) -> Dictionary:
	var node := {
		"region": region,
		"vertical": true,
		"left": null,
		"right": null
	}
	if depth >= MAX_SPLIT_DEPTH:
		return node

	var can_split_vertically := region.size.x >= 12
	var can_split_horizontally := region.size.y >= 12
	if not can_split_vertically and not can_split_horizontally:
		return node

	var split_vertically: bool
	if can_split_vertically and can_split_horizontally:
		if region.size.x > region.size.y * 1.2:
			split_vertically = true
		elif region.size.y > region.size.x * 1.2:
			split_vertically = false
		else:
			split_vertically = _rng.randi_range(0, 1) == 0
	else:
		split_vertically = can_split_vertically

	node["vertical"] = split_vertically
	if split_vertically:
		var split_at := _rng.randi_range(6, region.size.x - 6)
		var left_region := Rect2i(region.position, Vector2i(split_at, region.size.y))
		var right_region := Rect2i(Vector2i(region.position.x + split_at, region.position.y), Vector2i(region.size.x - split_at, region.size.y))
		node["left"] = _partition(left_region, depth + 1)
		node["right"] = _partition(right_region, depth + 1)
	else:
		var split_at := _rng.randi_range(6, region.size.y - 6)
		var top_region := Rect2i(region.position, Vector2i(region.size.x, split_at))
		var bottom_region := Rect2i(Vector2i(region.position.x, region.position.y + split_at), Vector2i(region.size.x, region.size.y - split_at))
		node["left"] = _partition(top_region, depth + 1)
		node["right"] = _partition(bottom_region, depth + 1)
	return node


func _carve_bsp(node: Dictionary) -> Array:
	if node["left"] == null:
		var room := _make_room(node["region"])
		_carve_room(room)
		return [room]

	var left_rooms: Array = _carve_bsp(node["left"])
	var right_rooms: Array = _carve_bsp(node["right"])
	var room_a: Rect2i = left_rooms[_rng.randi_range(0, left_rooms.size() - 1)]
	var room_b: Rect2i = right_rooms[_rng.randi_range(0, right_rooms.size() - 1)]
	_connect_rooms(_room_center(room_a), _room_center(room_b), node["vertical"])
	left_rooms.append_array(right_rooms)
	return left_rooms


func _make_room(region: Rect2i) -> Rect2i:
	var max_width: int = region.size.x - 2
	var max_height: int = region.size.y - 2
	var room_width: int = _rng.randi_range(mini(4, max_width), max_width)
	var room_height: int = _rng.randi_range(mini(4, max_height), max_height)
	var room_x: int = region.position.x + _rng.randi_range(1, region.size.x - room_width - 1)
	var room_y: int = region.position.y + _rng.randi_range(1, region.size.y - room_height - 1)
	return Rect2i(room_x, room_y, room_width, room_height)


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_grid[y][x] = true


func _connect_rooms(a: Vector2i, b: Vector2i, split_vertically: bool) -> void:
	if split_vertically:
		var middle_x := floori((a.x + b.x) * 0.5)
		_carve_horizontal(a.y, a.x, middle_x)
		_carve_vertical(middle_x, a.y, b.y)
		_carve_horizontal(b.y, middle_x, b.x)
	else:
		var middle_y := floori((a.y + b.y) * 0.5)
		_carve_vertical(a.x, a.y, middle_y)
		_carve_horizontal(middle_y, a.x, b.x)
		_carve_vertical(b.x, middle_y, b.y)


func _carve_horizontal(y: int, from_x: int, to_x: int) -> void:
	for x in range(mini(from_x, to_x), maxi(from_x, to_x) + 1):
		_carve_corridor_cell(Vector2i(x, y))


func _carve_vertical(x: int, from_y: int, to_y: int) -> void:
	for y in range(mini(from_y, to_y), maxi(from_y, to_y) + 1):
		_carve_corridor_cell(Vector2i(x, y))


func _carve_corridor_cell(cell: Vector2i) -> void:
	for y in range(cell.y, cell.y + 2):
		for x in range(cell.x, cell.x + 2):
			if x > 0 and x < GRID_WIDTH - 1 and y > 0 and y < GRID_HEIGHT - 1:
				_grid[y][x] = true


func _room_center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(int(room.size.x / 2), int(room.size.y / 2))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)


func _build_wall_collisions() -> void:
	var blockers := StaticBody2D.new()
	blockers.name = "GeneratedWallCollisions"
	blockers.collision_layer = 1
	blockers.collision_mask = 1
	for y in range(1, GRID_HEIGHT - 1):
		var x := 1
		while x < GRID_WIDTH - 1:
			if _grid[y][x]:
				x += 1
				continue
			var run_start := x
			while x < GRID_WIDTH - 1 and not _grid[y][x]:
				x += 1
			var run_width := x - run_start
			var shape_node := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(run_width * CELL_SIZE, CELL_SIZE)
			shape_node.shape = shape
			shape_node.position = Vector2((run_start + run_width * 0.5) * CELL_SIZE, (y + 0.5) * CELL_SIZE)
			blockers.add_child(shape_node)
	add_child(blockers)


func _draw() -> void:
	draw_rect(Rect2(0, 0, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE), VOID_COLOR)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell_rect := Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			if x == 0 or y == 0 or x == GRID_WIDTH - 1 or y == GRID_HEIGHT - 1:
				draw_rect(cell_rect, WALL_COLOR)
				draw_rect(cell_rect, WALL_TOP, false, 1.0)
			elif _grid[y][x]:
				var variation := posmod(x * 11 + y * 7 + _seed_value, 5)
				var tile_color: Color = FLOOR_A if variation < 3 else FLOOR_B
				draw_rect(cell_rect, tile_color)
				draw_rect(cell_rect, FLOOR_EDGE, false, 1.0)
				if variation == 0:
					draw_rect(Rect2(x * CELL_SIZE + 8, y * CELL_SIZE + 8, 3, 3), Color("415461"))
			elif _touches_floor(x, y):
				draw_rect(cell_rect, WALL_COLOR)
				draw_rect(cell_rect, WALL_SIDE, false, 1.0)
				draw_line(Vector2(x * CELL_SIZE, y * CELL_SIZE + 1), Vector2((x + 1) * CELL_SIZE, y * CELL_SIZE + 1), WALL_TOP, 2.0)

	for x in range(30, GRID_WIDTH * CELL_SIZE - 30, 120):
		draw_rect(Rect2(x, 8, 30, 3), ACCENT)
		draw_rect(Rect2(x, GRID_HEIGHT * CELL_SIZE - 11, 30, 3), ACCENT.darkened(0.35))


func _touches_floor(x: int, y: int) -> bool:
	return _grid[y - 1][x] or _grid[y + 1][x] or _grid[y][x - 1] or _grid[y][x + 1]
