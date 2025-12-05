# portal.gd
extends Area2D

@export var next_scene_path: String = "res://scenes/NextLevel.tscn" # Change this to your next map

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Player":  # or use 'body.is_in_group("player")' if you use groups
		change_scene()

func change_scene():
	var next_scene = load(next_scene_path)
	get_tree().change_scene_to_packed(next_scene)
