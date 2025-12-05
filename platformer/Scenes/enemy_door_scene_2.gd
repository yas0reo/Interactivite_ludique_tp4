extends Area2D

# Path to the next scene
@export var next_scene_path := "res://Scenes/level_2.tscn"

# Optional: Play door opening animation
@export var play_open_animation := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_in_area := false
var scene_changing := false

func _ready():
	# Connect the area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	# Check if the player entered
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = true
		
		# Optionally play the door opening animation
		if play_open_animation and animated_sprite:
			if animated_sprite.sprite_frames.has_animation("Open"):
				animated_sprite.play("Open")
				# Wait for animation to finish before changing scene
				await animated_sprite.animation_finished
		
		# Change to the next scene
		change_scene()


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = false


func change_scene() -> void:
	if scene_changing:
		return
	
	scene_changing = true
	
	# Optional: Add a small delay or fade effect here
	await get_tree().create_timer(0.1).timeout
	
	# Change to the next scene
	get_tree().change_scene_to_file(next_scene_path)
