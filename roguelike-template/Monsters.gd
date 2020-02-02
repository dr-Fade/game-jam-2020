extends Node

const MonstersScene = preload("res://Monsters.tscn")

enum Type {
	Anger, Fear, Apathy
}

class MonsterReference extends Reference:
	var tile: Vector2
	var sprite_node: Node2D
	var type: int
	
	func _init(game, x: int, y: int, type: int, tile_size: int):
		tile = Vector2(x,y)
		sprite_node = MonstersScene.instance()
		sprite_node.frame = type
		self.type = type
		sprite_node.position = tile * tile_size
		game.add_child(sprite_node)
	
	func remove():
		sprite_node.queue_free()