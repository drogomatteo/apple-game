extends Node

signal mode_daltonien_change(nouveau_mode: int)

var sound : bool = true
var daltonien : int = 0

func definir_mode_daltonien(mode : int):
	daltonien = mode
	mode_daltonien_change.emit(daltonien)
