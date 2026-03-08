extends Node

var grid_size := 8
var cell_size := 2

var world := 1
var level := 1

func random_cell() -> Vector2:
	return Vector2(
		randi() % grid_size,
		randi() % grid_size
	)

func close_enough(a: Vector2, b: Vector2, tolerance := 1.2) -> bool:
	return abs(a.x - b.x) <= tolerance and abs(a.y - b.y) <= tolerance

func next_level():
	level += 1

func next_world():
	world += 1
	level = 1

func current_level_path() -> String:
	return "res://scenes/levels/world" + str(world) + "/level" + str(level) + ".tscn"
