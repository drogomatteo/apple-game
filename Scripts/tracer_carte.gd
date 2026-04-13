extends Control
var scaling = 20

var Position_joueur = [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,1), Vector2(8,8)]
var Position_panier = Vector2(3,1)
var Positon_repère = Vector2(5,3)
var Position_arbre = [Vector2(1,0), Vector2(2,0)]
var rectangle = [Vector2(-9*scaling, -9*scaling), Vector2(9*scaling, -9*scaling), Vector2(9*scaling, 9*scaling), Vector2(-9*scaling, 9*scaling), Vector2(-9*scaling, -9*scaling)]



func _draw() -> void:
	for i in range(len(rectangle)-1):
		draw_line(rectangle[i], rectangle[i+1], Color.BLACK, 10)
	for i in range(len(Position_joueur)-1):
		var X = (Position_joueur[i] - Vector2(8,8)) * scaling
		var Y = (Position_joueur[i+1] - Vector2(8,8)) * scaling
		draw_line(X, Y, Color.DARK_BLUE, 3.0, true)
