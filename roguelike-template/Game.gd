extends Node2D

# Preloads

const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 10
const BORDER_SIZE = 2
const LEVEL_SIZE = Vector2(50,50)
const TILE_SIZE = 64

enum Tile {
	Floor, Stone, Wall
}

# Current level

var map = []
var rooms = []
var furniture = []
var brokenItems: int = 0

# Events

onready var tile_map = $TileMap
onready var player = $Player
var player_tile
const FurnitureScene = preload("res://Furniture.tscn")

func _input(event: InputEvent):
	if !event.is_pressed():
		return

	if event.is_action("Left"):
		try_move(-1,0)
	elif event.is_action("Right"):
		try_move(1,0)
	elif event.is_action("Up"):
		try_move(0,-1)
	elif event.is_action("Down"):
		try_move(0,1)
	elif event.is_action("FixHammer"):
		try_fix(0)
	elif event.is_action("FixTape"):
		try_fix(1)
	elif event.is_action("FixScrew"):
		try_fix(2)

func try_fix(typefix):
	for f in furniture:
		if f.tile.x == player_tile.x && f.tile.y == player_tile.y :
			f.fix()
			brokenItems = brokenItems - 1
	get_node("TimeAndProgress/FixedItems").set_text(str(brokenItems))

func try_move(dx, dy):
	var x = player_tile.x + dx
	var y = player_tile.y + dy
	
	var tile_type = Tile.Stone
	if x >= 0 && x < LEVEL_SIZE.x && y >=0 && y < LEVEL_SIZE.y:
		tile_type = map[x][y]
	
	match tile_type:
		Tile.Floor:
			player_tile = Vector2(x,y)
	
	update_visuals()

# Called when the node enters the scene tree for the first time.
func _ready():
	OS.set_window_size(Vector2(1024, 576))
	build_level()
	get_node("TimeAndProgress/FixedItems").set_text(str(brokenItems))

func build_level():
	rooms.clear()
	map.clear()
	tile_map.clear()
	
	randomize()
	
	for x in range(LEVEL_SIZE.x):
		map.append([])
		for y in range(LEVEL_SIZE.y):
			map[x].append(Tile.Stone)
			tile_map.set_cell(x, y, Tile.Stone)
	
	var free_regions = [Rect2(Vector2(BORDER_SIZE,BORDER_SIZE), LEVEL_SIZE - Vector2(BORDER_SIZE, BORDER_SIZE))]
	while !free_regions.empty():
		add_room(free_regions)
	
	place_furniture()
	break_furniture()
	connect_rooms()
	
	var start_room = rooms.front()
	var player_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
	var player_y = start_room.position.y + 1 + randi() % int(start_room.size.y - 2)
	player_tile = Vector2(player_x, player_y)
	
	update_visuals()

func update_visuals() -> void:
	player.position = player_tile * TILE_SIZE

class FurnitureReference extends Reference:
	var tile: Vector2
	var sprite_node: Node2D
	var type: int
	var is_damaged: bool = true
	var is_fixable: bool = true
	
	func fix():
		is_damaged = false
		sprite_node.frame = sprite_node.frame - 3
	
	func damage():
		is_damaged = true
		sprite_node.frame = sprite_node.frame + 3
		
	func destroy():
		is_fixable = false
	
	func _init(game, x: int, y: int, type: int, tile_size: int):
		tile = Vector2(x,y)
		sprite_node = FurnitureScene.instance()
		sprite_node.frame=type;
		sprite_node.position = tile * tile_size
		game.add_child(sprite_node)
	
	func _remove():
		sprite_node.queue_free()

func place_furniture():
	furniture.clear()
	for room in rooms:
		#Rect2(start_x, start_y, size_x, size_y)
		var top_left = Vector2(room.position.x + 1, room.position.y + 1) 
		var bottom_right = Vector2(room.end.x - 1, room.end.y - 1)
		for x in range(top_left.x, bottom_right.x):
			for y in range(top_left.y, bottom_right.y):
				if randi()%100 > 90:
					furniture.append(FurnitureReference.new(self, x, y, randi() % 3, TILE_SIZE))

func break_furniture():
	var cntbroken: int = 0
	for fur in furniture:
		if randi() % 2 == 1:
			fur.damage()
			cntbroken += 1
	brokenItems = cntbroken
	
	
func connect_rooms():
	var stone_graph = AStar.new()
	var point_id = 0
	for x in range(LEVEL_SIZE.x):
		for y in range(LEVEL_SIZE.y):
			if map[x][y] == Tile.Stone:
				stone_graph.add_point(point_id, Vector3(x,y,0))
				if x > 0 && map[x-1][y] == Tile.Stone:
					var left_point = stone_graph.get_closest_point(Vector3(x - 1, y, 0))
					stone_graph.connect_points(point_id, left_point)
				if y > 0 && map[x][y-1] == Tile.Stone:
					var above_point = stone_graph.get_closest_point(Vector3(x, y - 1, 0))
					stone_graph.connect_points(point_id, above_point)
				point_id += 1
	var room_graph = AStar.new()
	point_id = 0
	for room in rooms:
		var room_center = room.position + room.size / 2
		room_graph.add_point(point_id, Vector3(room_center.x, room_center.y, 0))
		point_id += 1
	while !is_everything_connected(room_graph):
		add_random_connection(stone_graph, room_graph)

func is_everything_connected(graph):
	var points = graph.get_points()
	var start = points.pop_back()
	for point in points:
		var path = graph.get_point_path(start, point)
		if !path:
			return false
	return true

func add_random_connection(stone_graph, room_graph):
	var start_room_id = get_least_connected_point(room_graph)
	var end_room_id = get_nearest_unconnected_point(room_graph, start_room_id)
	
	var start_position = pick_random_door_location(rooms[start_room_id])
	var end_position = pick_random_door_location(rooms[end_room_id])
	
	var closest_start_point = stone_graph.get_closest_point(start_position)
	var closest_end_point = stone_graph.get_closest_point(end_position)
	
	var path = stone_graph.get_point_path(closest_start_point, closest_end_point)
	assert(path)
	
	set_tile(start_position.x, start_position.y, Tile.Floor)
	set_tile(end_position.x, end_position.y, Tile.Floor)
	
	for position in path:
		set_tile(position.x, position.y, Tile.Floor)
	
	room_graph.connect_points(start_room_id, end_room_id)

func get_least_connected_point(graph):
	var point_ids = graph.get_points()
	var least
	var tied_for_least = []
	
	for point in point_ids:
		var count = graph.get_point_connections(point).size()
		if !least || count < least:
			least = count
			tied_for_least = [point]
		elif count == least:
			tied_for_least.append(point)
	
	return tied_for_least[randi() % tied_for_least.size()]

func get_nearest_unconnected_point(graph, target_point):
	var target_position = graph.get_point_position(target_point)
	var point_ids = graph.get_points()
	
	var nearest
	var tied_for_nearest = []
	
	for point in point_ids:
		if point == target_point:
			continue
		
		var path = graph.get_point_path(point, target_point)
		if path:
			continue
			
		var dist = (graph.get_point_position(point) - target_position).length()
		if !nearest || dist < nearest:
			nearest = dist
			tied_for_nearest = [point]
		elif dist == nearest:
			tied_for_nearest.append(point)
	
	return tied_for_nearest[randi() % tied_for_nearest.size()]

func pick_random_door_location(room):
	var options = []
	
	for x in range(room.position.x + 1, room.end.x - 2):
		options.append(Vector3(x, room.position.y, 0))
		options.append(Vector3(x, room.end.y - 1, 0))
	
	for y in range(room.position.y + 1, room.end.y - 2):
		options.append(Vector3(room.position.x, y, 0))
		options.append(Vector3(room.end.x - 1, y, 0))
	
	return options[randi() % options.size()]

func add_room(free_regions: Array) -> void:
	var region = free_regions[randi() % free_regions.size()]

	var room_start = Vector2(
		region.position.x, 
		region.position.y
	)
	
	var room_size = Vector2(
		MIN_ROOM_DIMENSION + randi() % (MAX_ROOM_DIMENSION - MIN_ROOM_DIMENSION),
		MIN_ROOM_DIMENSION + randi() % (MAX_ROOM_DIMENSION - MIN_ROOM_DIMENSION)
	)
	
	if region.end.x <= room_start.x + room_size.x:
		room_size.x = region.end.x - (room_start.x + room_size.x) 
	
	if region.end.y <= room_start.y + room_size.y:
		room_size.y = region.end.y - (room_start.y + room_size.y)
	
	if room_size.x < MIN_ROOM_DIMENSION || room_size.y < MIN_ROOM_DIMENSION:
		print("WTF???")
		
	var room = Rect2(room_start.x, room_start.y, room_size.x, room_size.y)
	rooms.append(room)
	
	for x in range(room_start.x, room_start.x + room_size.x):
		set_tile(x, room_start.y, Tile.Wall)
		set_tile(x, room_start.y + room_size.y - 1, Tile.Wall)
	
	for y in range(room_start.y + 1, room_start.y + room_size.y - 1):
		set_tile(room_start.x, y, Tile.Wall)
		set_tile(room_start.x + room_size.x - 1, y, Tile.Wall)
		for x in range(room_start.x + 1, room_start.x + room_size.x - 1):
			set_tile(x, y, Tile.Floor)
	
	cut_regions(free_regions)

func cut_regions(free_regions):
	free_regions.clear()
	for grid_x in range(BORDER_SIZE, LEVEL_SIZE.x - MAX_ROOM_DIMENSION, MAX_ROOM_DIMENSION):
		for grid_y in range(BORDER_SIZE, LEVEL_SIZE.y - MAX_ROOM_DIMENSION, MAX_ROOM_DIMENSION):
			var grid_cell = Rect2(grid_x, grid_y, grid_x + MAX_ROOM_DIMENSION, grid_y + MAX_ROOM_DIMENSION)
			var is_valid = true
			for room in rooms:
				if room.intersects(grid_cell):
					is_valid = false
					break
			if is_valid:
				free_regions.append(grid_cell)

func set_tile(x,y,type):
	map[x][y] = type
	tile_map.set_cell(x, y, type)

#func _process(delta):
