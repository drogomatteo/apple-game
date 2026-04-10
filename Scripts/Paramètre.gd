extends Node

var sound : bool = true
var daltonien : int = 0

func definir_mode_daltonien(mode : int):
	daltonien = mode
	Daltonien._mettre_a_jour_daltonien(daltonien)
