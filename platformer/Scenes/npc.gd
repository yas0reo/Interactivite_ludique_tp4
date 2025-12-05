# npc.gd
extends Node

# Easily changeable dialogue text
@export_multiline var dialogue_text: String = "Hello, traveler! Welcome to my humble village."
@export var interaction_range: float = 130.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var interaction_label = $InteractionPrompt
@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_label = $DialoguePanel/MarginContainer/DialogueLabel

var player_in_range := false
var is_interacting := false

func _ready():
	# Setup interaction area
	var collision_shape = interaction_area.get_node("CollisionShape2D")
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = interaction_range
	collision_shape.shape = circle_shape
	
	# Connect area signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Hide UI elements initially
	interaction_label.visible = false
	dialogue_panel.visible = false
	
	# Start idle animation
	animated_sprite.play("idle")
	
	# Set dialogue text
	dialogue_label.text = dialogue_text

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		interact()

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		if not is_interacting:
			interaction_label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		interaction_label.visible = false
		end_interaction()

func interact():
	if is_interacting:
		end_interaction()
	else:
		start_interaction()

func start_interaction():
	is_interacting = true
	interaction_label.visible = false
	dialogue_panel.visible = true
	
	# Switch to interacted animation if it exists
	if animated_sprite.sprite_frames.has_animation("interacted"):
		animated_sprite.play("interacted")

func end_interaction():
	is_interacting = false
	dialogue_panel.visible = false
	
	# Return to idle animation
	animated_sprite.play("idle")
	
	# Show interaction prompt again if player still in range
	if player_in_range:
		interaction_label.visible = true
