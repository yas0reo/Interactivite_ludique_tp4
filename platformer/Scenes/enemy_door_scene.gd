extends Area2D

# Path to the next scene
@export var next_scene_path := "res://Scenes/level_1.tscn"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

var player_in_area := false
var scene_changing := false
var is_open := false

# UI Label for instructions
var label: Label = null

func _ready():
	# Create label for player instructions
	label = Label.new()
	label.text = ""
	label.position = Vector2(-80, -120)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	# Connect the area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Check if all enemies are defeated
	check_enemies()

func _process(_delta):
	# Continuously check if enemies are defeated
	if not is_open:
		check_enemies()
	
	# Update label visibility and text
	if player_in_area:
		if is_open:
			label.text = "Press E to enter"
		else:
			var enemy_count = get_tree().get_nodes_in_group("enemies").size()
			label.text = "Defeat all enemies\n(" + str(enemy_count) + " left)"
	else:
		label.text = ""
	
	# Check for E key press to enter door
	if player_in_area and is_open and Input.is_action_just_pressed("interact"):
		change_scene()

func check_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0 and not is_open:
		open_door()

func open_door():
	is_open = true
	print("Door is now open!")
	
	# Play opening animation if available
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("Open"):
			animated_sprite.play("Open")

func _on_body_entered(body: Node) -> void:
	# Check if the player entered
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = true
		print("Player near door")

func _on_body_exited(body: Node) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		player_in_area = false
		print("Player left door area")

func change_scene() -> void:
	if scene_changing or not is_open:
		return
	
	scene_changing = true
	print("Changing to scene: ", next_scene_path)
	
	# Optional: Add a small delay
	await get_tree().create_timer(0.1).timeout
	
	# Change to the next scene
	get_tree().change_scene_to_file(next_scene_path)
