extends Node2D

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Preloads

var LEVEL_ROOM_COUNT
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 10
const BORDER_SIZE = 1
const LEVEL_SIZE = Vector2(50,50)
const TILE_SIZE = 64

enum Tile {
	Floor, Stone, Wall
}

enum Repair {
	Hammer=0, Screw=1, Tape=2
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
		try_fix(Repair.Hammer)
	elif event.is_action("FixScrew"):
		try_fix(Repair.Screw)
	elif event.is_action("FixTape"):
		try_fix(Repair.Tape)


func try_fix(typefix):
	for f in furniture:
		if f.tile.x == player_tile.x && f.tile.y == player_tile.y && f.is_damaged :
			f.fix(typefix) 
			if f.is_fixed:
				brokenItems = brokenItems - 1
	get_node("TimeAndProgress/FixedItems").set_text(str(brokenItems-1))


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
	get_node("TimeAndProgress/FixedItems").set_text(str(brokenItems-1))

func build_level():	
	LEVEL_ROOM_COUNT = (LEVEL_SIZE.x / MAX_ROOM_DIMENSION) * (LEVEL_SIZE.y / MAX_ROOM_DIMENSION) 
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
	for i in range(LEVEL_ROOM_COUNT):
		add_room(free_regions)
		if free_regions.empty():
			break
	
	place_furniture()
	brake_furniture()
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
	var oridginal_repair_array_size: int
	var performed_array_repair_size: int
	var sprite_node: Node2D
	var popup_node: Node2D
	var richtext_node: RichTextLabel
	var repair_array: Array
	var current_reqired_repair: int
	var type: int
	var is_damaged: bool = true
	var is_fixed: bool = true
	
	func fix(type_fix):
		if type_fix == current_reqired_repair :
			if repair_array.size() == 0 :
				is_fixed = true
				is_damaged = false
				popup_node.hide()
				performed_array_repair_size = performed_array_repair_size + 1
				richtext_node.set_text(str(performed_array_repair_size)+"/"+str(oridginal_repair_array_size))
				sprite_node.frame = sprite_node.frame - 3
			else:
				current_reqired_repair = repair_array.front()
				popup_node.frame=current_reqired_repair
				repair_array.pop_front()
				performed_array_repair_size = performed_array_repair_size + 1
				richtext_node.set_text(str(performed_array_repair_size)+"/"+str(oridginal_repair_array_size))
				

		
	
	func damage():
		is_fixed = false
		is_damaged = true
		sprite_node.frame = sprite_node.frame + 3
		var repair_array_size = randi() % 7 + 1
		oridginal_repair_array_size = repair_array_size+1
		for repair in range(0, repair_array_size):
			repair_array.append(randi() % 3)
		current_reqired_repair = repair_array.front()
		popup_node.show()
		popup_node.frame=current_reqired_repair
		richtext_node.show()
		richtext_node.set_text(str(performed_array_repair_size)+"/"+str(oridginal_repair_array_size))
		
	func destroy():
		is_fixed = false
	
	func _init(game, x: int, y: int, type: int, tile_size: int , r_array: Array):
		tile = Vector2(x,y)
		repair_array=r_array
		oridginal_repair_array_size = 0
		sprite_node = FurnitureScene.instance() 
		popup_node = sprite_node.get_child(0)
		popup_node.hide()
		richtext_node = sprite_node.get_child(1)
		richtext_node.hide()
		performed_array_repair_size = 0
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
					var r_arrray = []
					furniture.append(FurnitureReference.new(self, x, y, randi() % 3, TILE_SIZE, r_arrray))

func brake_furniture():
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
		options.append(Vector3(x, room.end.y, 0))
	
	for y in range(room.position.y + 1, room.end.y - 2):
		options.append(Vector3(room.position.x, y, 0))
		options.append(Vector3(room.end.x - 1, y, 0))
	
	return options[randi() % options.size()]

func add_room(free_regions: Array) -> void:
	var region = free_regions[randi() % free_regions.size()]

	var room_start = Vector2(
		region.position.x,# + randi() % int(region.size.x) - MIN_ROOM_DIMENSION, 
		region.position.y# + randi() % int(region.size.y) - MIN_ROOM_DIMENSION
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
