extends Area2D

@export var next_scene_path := "res://Scenes/win_screen.tscn"
@export var play_open_animation := false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_in_area := false
var scene_changing := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = true
		if play_open_animation and animated_sprite:
			if animated_sprite.sprite_frames.has_animation("Open"):
				animated_sprite.play("Open")
				await animated_sprite.animation_finished
		change_scene()


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = false


func change_scene() -> void:
	if scene_changing:
		return
	scene_changing = true
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file(next_scene_path)
