extends Node2D

# Preloads

const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 10
const BORDER_SIZE = 2
const LEVEL_SIZE = Vector2(50,50)
const TILE_SIZE = 64
const MONSTER_SIGHT = MIN_ROOM_DIMENSION
const MONSTER_ATTACK = 20
const DEBUFF_ACTIVATION_THRESHOLD = 60

enum Tile {
	Floor, Stone, Wall
}

enum Fix {
	Hammer, Screwdriver, Ducttape
}

# Current level

var map = []
var rooms = []
var furniture = []
var monsters = []
var floor_graph = AStar.new()
var broken_items: int = 0

var player_tile
var debuffs = [0,0,0]

# Preloads

onready var tile_map = $TileMap
onready var player = $Player
onready var Monsters = load("res://Monsters.gd").new()
const FurnitureScene = preload("res://Furniture.tscn")

onready var oof = load("res://audio/oof.wav")
onready var whispers = load("res://audio/whispers.wav")
onready var clock = load("res://audio/clock.ogg")
onready var hammer = load("res://audio/hammer.wav")
onready var screwdriver = load("res://audio/screwdriver.wav")
onready var ducttape = load("res://audio/ducttape.wav")

onready var anger_debuff_value = get_node("ItemsAndControl/Debuffs/AngerValue")
onready var fear_debuff_value = get_node("ItemsAndControl/Debuffs/FearValue")
onready var apathy_debuff_value = get_node("ItemsAndControl/Debuffs/ApathyValue")

# Events

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
		try_fix(Fix.Hammer)
	elif event.is_action("FixScrew"):
		try_fix(Fix.Screwdriver)
	elif event.is_action("FixTape"):
		try_fix(Fix.Ducttape)

func try_fix(type_of_fix):
	for f in furniture:
		if f.tile == player_tile && f.is_damaged :
			f.fix(type_of_fix) 
			match type_of_fix:
				Fix.Hammer:
					$Fx/Actions.stream = hammer
				Fix.Screwdriver:
					$Fx/Actions.stream = screwdriver
				Fix.Ducttape:
					$Fx/Actions.stream = ducttape
			$Fx/Actions.play()
			if f.is_fixed:
				broken_items = broken_items - 1
			break
	get_node("TimeAndProgress/FixedItems").set_text(str(broken_items))

func try_move(dx, dy):
	for type in Monsters.Type.values():
		if debuffs[type] > 0:
			debuffs[type] -= 1
	
	var x = player_tile.x + dx
	var y = player_tile.y + dy
	
	var tile_type = Tile.Stone
	if x >= 0 && x < LEVEL_SIZE.x && y >=0 && y < LEVEL_SIZE.y:
		tile_type = map[x][y]
	
	if tile_type == Tile.Floor:
		if debuffs[Monsters.Type.Apathy] > 0:
			randomize()
			if randi() % DEBUFF_ACTIVATION_THRESHOLD > debuffs[Monsters.Type.Apathy]:
				player_tile = Vector2(x,y)
		else:
			player_tile = Vector2(x,y)
	
	var player_point = floor_graph.get_closest_point(Vector3(player_tile.x, player_tile.y, 0))
	for monster in monsters:
		if monster.tile.x != x || monster.tile.y != y:
			var monster_point = floor_graph.get_closest_point(Vector3(monster.tile.x, monster.tile.y, 0))
			var path = floor_graph.get_point_path(monster_point, player_point)
			if path && path.size() < MONSTER_SIGHT && randi() % 100 > 10:
				monster.tile.x = path[1].x
				monster.tile.y = path[1].y
				monster.sprite_node.position = monster.tile * TILE_SIZE
		if monster.tile.x == player_tile.x && monster.tile.y == player_tile.y:
			debuffs[monster.type] += MONSTER_ATTACK
			$Fx/Actions.stream = oof
			$Fx/Actions.play()
			monster.remove()
			monsters.erase(monster)
	var whispers_volume = -50
	for debuff in debuffs:
		if whispers_volume >= 0:
			break
		whispers_volume += debuff
	$Fx/Whisper.volume_db = whispers_volume
	update_visuals()

# Called when the node enters the scene tree for the first time.
func _ready():
	OS.set_window_size(Vector2(1024, 576))
	build_level()
	init_sound()
	get_node("TimeAndProgress/FixedItems").set_text(str(broken_items))

func init_sound():
#	whispers.loop_mode = 1
#
#	$Fx/Whisper.stream = whispers
#	$Fx/Whisper.volume_db = -50
#	$Fx/Whisper.play()
	
	clock.loop = 1

	$Fx/Clock.stream = clock
	$Fx/Clock.volume_db = +10
	$Fx/Clock.play()

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
	
	spawn_furniture()
	spawn_monsters()
	connect_rooms()
	create_floor_graph()
	
	var start_room = rooms.front()
	var player_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
	var player_y = start_room.position.y + 1 + randi() % int(start_room.size.y - 2)
	player_tile = Vector2(player_x, player_y)
	
	update_visuals()

func update_visuals() -> void:
	player.position = player_tile * TILE_SIZE
	anger_debuff_value.set_text(str(debuffs[Monsters.Type.Anger]))
	fear_debuff_value.set_text(str(debuffs[Monsters.Type.Fear]))
	apathy_debuff_value.set_text(str(debuffs[Monsters.Type.Apathy]))

class FurnitureReference extends Reference:
	var tile: Vector2
	var original_repair_array_size: int
	var performed_repair_array_size: int
	var sprite_node: Node2D
	var popup_node: Node2D
	var richtext_node: RichTextLabel
	var repair_array: Array
	var current_required_repair: int
	var type: int
	var is_damaged: bool = false
	var is_fixed: bool = true
	
	func fix(type_fix):
		if type_fix == current_required_repair:
			if repair_array.size() == 0 :
				is_fixed = true
				is_damaged = false
				popup_node.hide()
				performed_repair_array_size += 1
				richtext_node.set_text(str(performed_repair_array_size)+"/"+str(original_repair_array_size))
				sprite_node.frame = sprite_node.frame - 3
			else:
				current_required_repair = repair_array.front()
				popup_node.frame = current_required_repair
				repair_array.pop_front()
				performed_repair_array_size += 1
				richtext_node.set_text(str(performed_repair_array_size)+"/"+str(original_repair_array_size))
		else :
			damage()
	
	func damage():
		repair_array.clear()
		performed_repair_array_size = 0
		is_fixed = false
		is_damaged = true
		sprite_node.frame = sprite_node.frame + 3
		var repair_array_size = randi() % 7 + 1
		original_repair_array_size = repair_array_size+1
		for repair in range(0, repair_array_size):
			repair_array.append(randi() % 3)
		current_required_repair = repair_array.front()
		popup_node.show()
		popup_node.frame=current_required_repair
		richtext_node.show()
		richtext_node.set_text(str(performed_repair_array_size)+"/"+str(original_repair_array_size))
		
	func destroy():
		is_fixed = false
	
	func _init(game, x: int, y: int, type: int, tile_size: int , r_array: Array):
		tile = Vector2(x,y)
		repair_array=r_array
		original_repair_array_size = 0
		sprite_node = FurnitureScene.instance() 
		popup_node = sprite_node.get_child(0)
		popup_node.hide()
		richtext_node = sprite_node.get_child(1)
		richtext_node.hide()
		performed_repair_array_size = 0
		sprite_node.frame=type;
		sprite_node.position = tile * tile_size
		game.add_child(sprite_node)
	
	func remove():
		sprite_node.queue_free()

func spawn_furniture():
	furniture.clear()
	var count_broken: int = 0
	for room in rooms:
		#Rect2(start_x, start_y, size_x, size_y)
		var top_left = Vector2(room.position.x + 1, room.position.y + 1) 
		var bottom_right = Vector2(room.end.x - 1, room.end.y - 1)
		for x in range(top_left.x, bottom_right.x):
			for y in range(top_left.y, bottom_right.y):
				if randi() % 100 > 90:
					var new_furniture = FurnitureReference.new(self, x, y, randi() % 3, TILE_SIZE, [])
					if randi() % 2 == 1:
						new_furniture.damage()
						count_broken += 1
					furniture.append(new_furniture)
	broken_items = count_broken

func spawn_monsters():
	monsters.clear()
	for room in rooms:
		if room == rooms.front():
			continue
		var top_left = Vector2(room.position.x + 1, room.position.y + 1) 
		var bottom_right = Vector2(room.end.x - 1, room.end.y - 1)
		for x in range(top_left.x, bottom_right.x):
			for y in range(top_left.y, bottom_right.y):
				if randi() % 100 > 95:
					monsters.append(Monsters.MonsterReference.new(self, x, y, randi() % 3, TILE_SIZE))

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

func create_floor_graph():
	var point_id = 0
	for x in range(LEVEL_SIZE.x):
		for y in range(LEVEL_SIZE.y):
			if map[x][y] == Tile.Floor:
				floor_graph.add_point(point_id, Vector3(x,y,0))
				if x > 0 && map[x-1][y] == Tile.Floor:
					var left_point = floor_graph.get_closest_point(Vector3(x - 1, y, 0))
					floor_graph.connect_points(point_id, left_point)
				if y > 0 && map[x][y-1] == Tile.Floor:
					var above_point = floor_graph.get_closest_point(Vector3(x, y - 1, 0))
					floor_graph.connect_points(point_id, above_point)
				point_id += 1

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

	rooms.append(Rect2(room_start.x, room_start.y, room_size.x, room_size.y))
	
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
