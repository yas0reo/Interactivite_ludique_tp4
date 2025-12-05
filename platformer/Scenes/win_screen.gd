extends Control

@onready var play_again_button: Button = $CenterContainer/VBoxContainer/Button

func _ready():
	play_again_button.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main_Menu.tscn")
