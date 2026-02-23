extends Node

class_name House

var house_scene = preload("res://scenes/house.tscn")

var instance: Node3D

func _init(pos: Vector3, rot: Vector3):
	instance = house_scene.instantiate()
	instance.position = pos
	instance.rotation = rot
