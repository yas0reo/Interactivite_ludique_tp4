extends Node2D

@export var interaction_range := 80.0
var player_in_range := false
var sign_open := false
var player: CharacterBody2D = null
@onready var interaction_label = $InteractionLabel
@onready var sign_panel = $SignPanel

# Tout cacher

func _ready():
	if interaction_label:
		interaction_label.visible = false
	if sign_panel:
		sign_panel.visible = false
# Parametre d'interactivité

func _process(_delta):
	check_player_distance()
	if player_in_range and not sign_open:
		if interaction_label:
			interaction_label.visible = true
	else:
		if interaction_label:
			interaction_label.visible = false
	if player_in_range and Input.is_action_just_pressed("interact"):
		toggle_sign()

func check_player_distance():
	if not player:
		player = Global.playerBody
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= interaction_range:
			player_in_range = true
		else:
			player_in_range = false
			if sign_open:
				close_sign()

func toggle_sign():
	if sign_open:
		close_sign()
	else:
		open_sign()

func open_sign():
	sign_open = true
	if sign_panel:
		sign_panel.visible = true

func close_sign():
	sign_open = false
	if sign_panel:
		sign_panel.visible = false
