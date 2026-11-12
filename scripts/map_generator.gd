extends Node2D

const GRID_WIDTH := 160
const GRID_HEIGHT := 90
const CELL_SIZE := 32
const ROOM_COUNT := 6
const MIN_LEAF_WIDTH := 36
const MIN_LEAF_HEIGHT := 22
const ROOM_MARGIN := 3
const BOSS_ROOM_MARGIN := 2
const CORRIDOR_CLEARANCE := 2
const ROOM_MIN_WIDTH := 24
const ROOM_MAX_WIDTH := 30
const ROOM_MIN_HEIGHT := 12
const ROOM_MAX_HEIGHT := 16
const BOSS_ROOM_WIDTH := 32
const BOSS_ROOM_HEIGHT := 18
const START_REGION := Rect2i(1, 1, GRID_WIDTH - 2, GRID_HEIGHT - 2)
const WORLD_WIDTH := GRID_WIDTH * CELL_SIZE
const WORLD_HEIGHT := GRID_HEIGHT * CELL_SIZE

const VOID_COLOR := Color("080f18")
const FLOOR_A := Color("202d38")
const WALL_COLOR := Color("101a23")
const WALL_TOP := Color("3b5665")
const WALL_SIDE := Color("182631")
const ACCENT := Color("49b9c8")

var _rng := RandomNumberGenerator.new()
var _grid: Array = []
var _floor_tiles: Array[Texture2D] = []
var _room_doors: Dictionary = {}
var _seed_value := 0
var _visible_grid_rect := Rect2i()
var _start_room := Rect2i()
var _boss_room := Rect2i()

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn


func _ready() -> void:
	_rng.randomize()
	_seed_value = _rng.randi()
	_load_floor_tiles()
	_room_doors.clear()
	_initialize_grid()
	var bsp_root := _partition(START_REGION, ROOM_COUNT)
	var leaves := _collect_leaves(bsp_root)
	var start_leaf := _find_start_leaf(leaves)
	var boss_leaf := _find_farthest_leaf(leaves, start_leaf["region"].position, _region_center(start_leaf["region"]))
	var rooms := _carve_bsp(bsp_root, start_leaf["region"].position, boss_leaf["region"].position)
	if not rooms.is_empty():
		_start_room = start_leaf["room"]
		_boss_room = boss_leaf["room"]
		player_spawn.position = _cell_center(_room_center(_start_room))
		boss_spawn.position = _cell_center(_room_center(_boss_room))
	_build_wall_collisions()
	_visible_grid_rect = _get_visible_grid_rect()
	queue_redraw()


func _load_floor_tiles() -> void:
	_floor_tiles.clear()
	for tile_index in range(1, 65):
		if tile_index == 38:
			continue
		var tile_path := "res://assets/map resources/Fields/1 Tiles/FieldsTile_%02d.png" % tile_index
		var tile := load(tile_path) as Texture2D
		if tile != null:
			_floor_tiles.append(tile)


func _process(_delta: float) -> void:
	var next_visible_rect := _get_visible_grid_rect()
	if next_visible_rect != _visible_grid_rect:
		_visible_grid_rect = next_visible_rect
		queue_redraw()


func _initialize_grid() -> void:
	_grid.clear()
	for y in range(GRID_HEIGHT):
		var row: Array[bool] = []
		for _x in range(GRID_WIDTH):
			row.append(false)
		_grid.append(row)


func _partition(region: Rect2i, target_leaves: int) -> Dictionary:
	var node := {
		"region": region,
		"vertical": true,
		"left": null,
		"right": null
	}
	if target_leaves <= 1:
		return node

	var can_split_vertically := region.size.x >= MIN_LEAF_WIDTH * 2
	var can_split_horizontally := region.size.y >= MIN_LEAF_HEIGHT * 2
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

	var left_leaf_count: int = int(target_leaves / 2)
	var right_leaf_count: int = target_leaves - left_leaf_count
	node["vertical"] = split_vertically
	if split_vertically:
		var split_at := _rng.randi_range(MIN_LEAF_WIDTH, region.size.x - MIN_LEAF_WIDTH)
		var left_region := Rect2i(region.position, Vector2i(split_at, region.size.y))
		var right_region := Rect2i(Vector2i(region.position.x + split_at, region.position.y), Vector2i(region.size.x - split_at, region.size.y))
		node["left"] = _partition(left_region, left_leaf_count)
		node["right"] = _partition(right_region, right_leaf_count)
	else:
		var split_at := _rng.randi_range(MIN_LEAF_HEIGHT, region.size.y - MIN_LEAF_HEIGHT)
		var top_region := Rect2i(region.position, Vector2i(region.size.x, split_at))
		var bottom_region := Rect2i(Vector2i(region.position.x, region.position.y + split_at), Vector2i(region.size.x, region.size.y - split_at))
		node["left"] = _partition(top_region, left_leaf_count)
		node["right"] = _partition(bottom_region, right_leaf_count)
	return node


func _collect_leaves(node: Dictionary) -> Array:
	if node["left"] == null:
		return [node]
	var leaves: Array = _collect_leaves(node["left"])
	leaves.append_array(_collect_leaves(node["right"]))
	return leaves


func _find_start_leaf(leaves: Array) -> Dictionary:
	var best_leaf: Dictionary = leaves[0]
	var world_center := Vector2i(int(GRID_WIDTH / 2), int(GRID_HEIGHT / 2))
	var best_distance := INF
	for leaf in leaves:
		var region: Rect2i = leaf["region"]
		var distance := _region_center(region).distance_squared_to(world_center)
		if distance < best_distance:
			best_distance = distance
			best_leaf = leaf
	return best_leaf


func _find_farthest_leaf(leaves: Array, excluded_position: Vector2i, origin: Vector2i) -> Dictionary:
	var best_leaf: Dictionary = leaves[0]
	var best_distance := -1
	for leaf in leaves:
		var region: Rect2i = leaf["region"]
		if region.position == excluded_position:
			continue
		var distance := _region_center(region).distance_squared_to(origin)
		if distance > best_distance:
			best_distance = distance
			best_leaf = leaf
	return best_leaf


func _region_center(region: Rect2i) -> Vector2i:
	return region.position + Vector2i(int(region.size.x / 2), int(region.size.y / 2))


func _carve_bsp(node: Dictionary, start_position: Vector2i, boss_position: Vector2i) -> Array:
	if node["left"] == null:
		var region: Rect2i = node["region"]
		var role := "normal"
		if region.position == start_position:
			role = "start"
		elif region.position == boss_position:
			role = "boss"
		var room := _make_room(region, role)
		node["room"] = room
		_carve_room(room)
		return [{"room": room, "role": role}]

	var left_rooms: Array = _carve_bsp(node["left"], start_position, boss_position)
	var right_rooms: Array = _carve_bsp(node["right"], start_position, boss_position)
	var left_connections := _connection_candidates(left_rooms)
	var right_connections := _connection_candidates(right_rooms)
	var entry_a: Dictionary = left_connections[_rng.randi_range(0, left_connections.size() - 1)]
	var entry_b: Dictionary = right_connections[_rng.randi_range(0, right_connections.size() - 1)]
	var room_a: Rect2i = entry_a["room"]
	var room_b: Rect2i = entry_b["room"]
	_connect_rooms(room_a, room_b, node["vertical"], node["region"])
	left_rooms.append_array(right_rooms)
	return left_rooms


func _connection_candidates(room_entries: Array) -> Array:
	var candidates: Array = []
	for entry in room_entries:
		if entry["role"] != "boss":
			candidates.append(entry)
	if candidates.is_empty():
		return room_entries
	return candidates


func _make_room(region: Rect2i, role: String) -> Rect2i:
	var max_width: int = region.size.x - 2
	var max_height: int = region.size.y - 2
	var room_margin := BOSS_ROOM_MARGIN if role == "boss" else ROOM_MARGIN
	var room_width: int
	var room_height: int
	match role:
		"start":
			room_width = _rng.randi_range(12, 14)
			room_height = _rng.randi_range(8, 10)
		"boss":
			room_width = mini(BOSS_ROOM_WIDTH, max_width)
			room_height = mini(BOSS_ROOM_HEIGHT, max_height)
		_:
			room_width = _rng.randi_range(ROOM_MIN_WIDTH, mini(ROOM_MAX_WIDTH, max_width))
			room_height = _rng.randi_range(ROOM_MIN_HEIGHT, mini(ROOM_MAX_HEIGHT, max_height))
	var room_x: int = _rng.randi_range(region.position.x + room_margin, region.end.x - room_width - room_margin)
	var room_y: int = _rng.randi_range(region.position.y + room_margin, region.end.y - room_height - room_margin)
	return Rect2i(room_x, room_y, room_width, room_height)


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_grid[y][x] = true


func _connect_rooms(room_a: Rect2i, room_b: Rect2i, split_vertically: bool, bounds: Rect2i) -> void:
	var side_a := "east" if split_vertically else "south"
	var side_b := "west" if split_vertically else "north"
	var doors_a := _get_available_doors(room_a, side_a, bounds)
	var doors_b := _get_available_doors(room_b, side_b, bounds)
	if doors_a.is_empty() or doors_b.is_empty():
		push_error("BSP could not find a free doorway for a room connection.")
		return

	var chosen_a := Vector2i.ZERO
	var chosen_b := Vector2i.ZERO
	var chosen_path: Array[Vector2i] = []
	for _attempt in range(32):
		chosen_a = doors_a[_rng.randi_range(0, doors_a.size() - 1)]
		chosen_b = doors_b[_rng.randi_range(0, doors_b.size() - 1)]
		chosen_path = _find_corridor_path(
			_door_outside_anchor(chosen_a, side_a),
			_door_outside_anchor(chosen_b, side_b),
			bounds,
			_door_clearance_cells(room_a, chosen_a, side_a),
			_door_clearance_cells(room_b, chosen_b, side_b)
		)
		if not chosen_path.is_empty():
			break

	if chosen_path.is_empty():
		for door_a in doors_a:
			for door_b in doors_b:
				chosen_path = _find_corridor_path(
					_door_outside_anchor(door_a, side_a),
					_door_outside_anchor(door_b, side_b),
					bounds,
					_door_clearance_cells(room_a, door_a, side_a),
					_door_clearance_cells(room_b, door_b, side_b)
				)
				if not chosen_path.is_empty():
					chosen_a = door_a
					chosen_b = door_b
					break
			if not chosen_path.is_empty():
				break

	if chosen_path.is_empty():
		push_error("BSP could not route a corridor without crossing an existing room or hallway.")
		return

	_register_room_door(room_a, side_a, chosen_a)
	_register_room_door(room_b, side_b, chosen_b)
	for anchor in chosen_path:
		_carve_corridor_block(anchor)


func _get_available_doors(room: Rect2i, side: String, bounds: Rect2i) -> Array[Vector2i]:
	var doors: Array[Vector2i] = []
	match side:
		"east", "west":
			var x := room.end.x - 1 if side == "east" else room.position.x
			for y in range(room.position.y + 1, room.end.y - 2):
				var door := Vector2i(x, y)
				if not _door_is_used(room, side, door) and _door_is_clear(room, door, side, bounds):
					doors.append(door)
		"north", "south":
			var y := room.position.y if side == "north" else room.end.y - 1
			for x in range(room.position.x + 1, room.end.x - 2):
				var door := Vector2i(x, y)
				if not _door_is_used(room, side, door) and _door_is_clear(room, door, side, bounds):
					doors.append(door)
	return doors


func _door_is_used(room: Rect2i, side: String, door: Vector2i) -> bool:
	var used_by_side: Dictionary = _room_doors.get(room.position, {})
	var used_coordinates: Array = used_by_side.get(side, [])
	var coordinate: int = door.y if side == "east" or side == "west" else door.x
	for used_coordinate in used_coordinates:
		if abs(coordinate - used_coordinate) < 3:
			return true
	return false


func _door_is_clear(room: Rect2i, door: Vector2i, side: String, bounds: Rect2i) -> bool:
	var allowed_floor_cells := _door_clearance_cells(room, door, side)
	return _can_place_corridor_block(_door_outside_anchor(door, side), bounds, allowed_floor_cells)


func _door_clearance_cells(room: Rect2i, door: Vector2i, side: String) -> Array[Vector2i]:
	var allowed: Array[Vector2i] = []
	var inward: Vector2i
	var across: Vector2i
	match side:
		"east":
			inward = Vector2i.LEFT
			across = Vector2i.DOWN
		"west":
			inward = Vector2i.RIGHT
			across = Vector2i.DOWN
		"south":
			inward = Vector2i.UP
			across = Vector2i.RIGHT
		_:
			inward = Vector2i.DOWN
			across = Vector2i.RIGHT
	for depth in range(CORRIDOR_CLEARANCE + 1):
		for offset in range(-CORRIDOR_CLEARANCE, 2 + CORRIDOR_CLEARANCE):
			var cell := door + inward * depth + across * offset
			if room.has_point(cell):
				allowed.append(cell)
	return allowed


func _door_outside_anchor(door: Vector2i, side: String) -> Vector2i:
	match side:
		"east":
			return door + Vector2i.RIGHT
		"west":
			return door + Vector2i.LEFT * 2
		"south":
			return door + Vector2i.DOWN
		_:
			return door + Vector2i.UP * 2


func _find_corridor_path(start: Vector2i, goal: Vector2i, bounds: Rect2i, start_door: Array[Vector2i], goal_door: Array[Vector2i]) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var allowed_floor_cells: Array[Vector2i] = []
	allowed_floor_cells.append_array(start_door)
	allowed_floor_cells.append_array(goal_door)
	if not _can_place_corridor_block(start, bounds, allowed_floor_cells) or not _can_place_corridor_block(goal, bounds, allowed_floor_cells):
		return path

	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var queue_index := 0
	while queue_index < queue.size():
		var current := queue[queue_index]
		queue_index += 1
		if current == goal:
			break
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if came_from.has(next):
				continue
			if not _can_place_corridor_block(next, bounds, allowed_floor_cells):
				continue
			came_from[next] = current
			queue.append(next)

	if not came_from.has(goal):
		return path
	var current := goal
	while current != start:
		path.append(current)
		current = Vector2i(came_from[current])
	path.append(start)
	path.reverse()
	return path


func _can_place_corridor_block(anchor: Vector2i, bounds: Rect2i, allowed_floor_cells: Array) -> bool:
	for y in range(anchor.y, anchor.y + 2):
		for x in range(anchor.x, anchor.x + 2):
			var cell := Vector2i(x, y)
			if not bounds.has_point(cell) or not _is_inside_world(cell):
				return false
			if _grid[y][x]:
				return false
			for near_y in range(cell.y - CORRIDOR_CLEARANCE, cell.y + CORRIDOR_CLEARANCE + 1):
				for near_x in range(cell.x - CORRIDOR_CLEARANCE, cell.x + CORRIDOR_CLEARANCE + 1):
					var nearby := Vector2i(near_x, near_y)
					if not _is_inside_world(nearby):
						return false
					if _grid[near_y][near_x] and not allowed_floor_cells.has(nearby):
						return false
	return true


func _carve_corridor_block(anchor: Vector2i) -> void:
	for y in range(anchor.y, anchor.y + 2):
		for x in range(anchor.x, anchor.x + 2):
			_grid[y][x] = true


func _is_inside_world(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.x < GRID_WIDTH - 1 and cell.y > 0 and cell.y < GRID_HEIGHT - 1


func _register_room_door(room: Rect2i, side: String, door: Vector2i) -> void:
	var used_by_side: Dictionary = _room_doors.get(room.position, {})
	var used_coordinates: Array = used_by_side.get(side, [])
	used_coordinates.append(door.y if side == "east" or side == "west" else door.x)
	used_by_side[side] = used_coordinates
	_room_doors[room.position] = used_by_side


func _room_center(room: Rect2i) -> Vector2i:
	return _region_center(room)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)


func _build_wall_collisions() -> void:
	var blockers := StaticBody2D.new()
	blockers.name = "GeneratedWallCollisions"
	blockers.collision_layer = 1
	blockers.collision_mask = 1
	for y in range(GRID_HEIGHT):
		if y == 0 or y == GRID_HEIGHT - 1:
			continue
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
	_add_world_bounds(blockers)
	add_child(blockers)


func _add_world_bounds(blockers: StaticBody2D) -> void:
	_add_wall_shape(blockers, Vector2(WORLD_WIDTH * 0.5, CELL_SIZE * 0.5), Vector2(WORLD_WIDTH, CELL_SIZE))
	_add_wall_shape(blockers, Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT - CELL_SIZE * 0.5), Vector2(WORLD_WIDTH, CELL_SIZE))
	_add_wall_shape(blockers, Vector2(CELL_SIZE * 0.5, WORLD_HEIGHT * 0.5), Vector2(CELL_SIZE, WORLD_HEIGHT))
	_add_wall_shape(blockers, Vector2(WORLD_WIDTH - CELL_SIZE * 0.5, WORLD_HEIGHT * 0.5), Vector2(CELL_SIZE, WORLD_HEIGHT))


func _add_wall_shape(blockers: StaticBody2D, position: Vector2, size: Vector2) -> void:
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = position
	blockers.add_child(shape_node)


func configure_player(player: Node2D) -> void:
	var camera := Camera2D.new()
	camera.name = "MapCamera"
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_WIDTH
	camera.limit_bottom = WORLD_HEIGHT
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()
	camera.reset_smoothing()
	_visible_grid_rect = _get_visible_grid_rect()
	queue_redraw()


func _get_visible_grid_rect() -> Rect2i:
	var center := player_spawn.global_position
	var zoom := Vector2.ONE
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		center = camera.get_screen_center_position()
		zoom = camera.zoom
	var view_size := get_viewport_rect().size / zoom
	var half_view := view_size * 0.5
	var start := Vector2i(
		clampi(floori((center.x - half_view.x) / CELL_SIZE) - 1, 0, GRID_WIDTH),
		clampi(floori((center.y - half_view.y) / CELL_SIZE) - 1, 0, GRID_HEIGHT)
	)
	var end := Vector2i(
		clampi(ceili((center.x + half_view.x) / CELL_SIZE) + 1, 0, GRID_WIDTH),
		clampi(ceili((center.y + half_view.y) / CELL_SIZE) + 1, 0, GRID_HEIGHT)
	)
	return Rect2i(start, end - start)


func _draw() -> void:
	var visible_end := _visible_grid_rect.end
	var background_position := Vector2(_visible_grid_rect.position * CELL_SIZE)
	var background_size := Vector2(_visible_grid_rect.size * CELL_SIZE)
	draw_rect(Rect2(background_position, background_size), VOID_COLOR)
	for y in range(_visible_grid_rect.position.y, visible_end.y):
		for x in range(_visible_grid_rect.position.x, visible_end.x):
			var cell_rect := Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			if x == 0 or y == 0 or x == GRID_WIDTH - 1 or y == GRID_HEIGHT - 1:
				draw_rect(cell_rect, WALL_COLOR)
				draw_rect(cell_rect, WALL_TOP, false, 1.0)
			elif _grid[y][x]:
				var cell := Vector2i(x, y)
				var tile_tint := Color.WHITE
				if _start_room.has_point(cell):
					tile_tint = Color("e6f8f8")
				elif _boss_room.has_point(cell):
					tile_tint = Color("fff0e2")
				if not _floor_tiles.is_empty():
					var variation := posmod(x * 17 + y * 31 + _seed_value, _floor_tiles.size())
					draw_texture_rect(_floor_tiles[variation], cell_rect, false, tile_tint)
				else:
					draw_rect(cell_rect, FLOOR_A)
			elif _touches_floor(x, y):
				draw_rect(cell_rect, WALL_COLOR)
				draw_rect(cell_rect, WALL_SIDE, false, 1.0)
				draw_line(Vector2(x * CELL_SIZE, y * CELL_SIZE + 1), Vector2((x + 1) * CELL_SIZE, y * CELL_SIZE + 1), WALL_TOP, 2.0)

	if _visible_grid_rect.position.y == 0:
		for x in range(_visible_grid_rect.position.x, visible_end.x, 4):
			draw_rect(Rect2(x * CELL_SIZE + 6, 8, 30, 3), ACCENT)
	if visible_end.y == GRID_HEIGHT:
		for x in range(_visible_grid_rect.position.x, visible_end.x, 4):
			draw_rect(Rect2(x * CELL_SIZE + 6, WORLD_HEIGHT - 11, 30, 3), ACCENT.darkened(0.35))


func _touches_floor(x: int, y: int) -> bool:
	return _grid[y - 1][x] or _grid[y + 1][x] or _grid[y][x - 1] or _grid[y][x + 1]
