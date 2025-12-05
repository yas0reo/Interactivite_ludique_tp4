extends CanvasLayer

var is_paused := false
var original_music_volume := 0.0

@onready var pause_panel = $PausePanel
@onready var options_panel = $OptionsPanel
@onready var volume_slider = $OptionsPanel/MarginContainer/VBoxContainer/VolumeControl/VolumeSlider
@onready var volume_label = $OptionsPanel/MarginContainer/VBoxContainer/VolumeControl/VolumeValue

func _ready():
	pause_panel.visible = false
	options_panel.visible = false
	
	# Option volume
	volume_slider.value = 10
	update_volume_label()
	

	$PausePanel/MarginContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$PausePanel/MarginContainer/VBoxContainer/OptionsButton.pressed.connect(_on_options_pressed)
	$PausePanel/MarginContainer/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	
	$OptionsPanel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)

func _input(event):
	if event.is_action_pressed("Pause"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		pause_game()
	else:
		resume_game()

func pause_game():
	get_tree().paused = true
	pause_panel.visible = true
	options_panel.visible = false
	adjust_music_volume(-3.0)

func resume_game():
	get_tree().paused = false
	pause_panel.visible = false
	options_panel.visible = false
	adjust_music_volume(original_music_volume)

func adjust_music_volume(db_change: float):

	var audio_players = get_tree().get_nodes_in_group("music")
	for player in audio_players:
		if player is AudioStreamPlayer or player is AudioStreamPlayer2D:
			if db_change == original_music_volume:
				player.volume_db = original_music_volume
			else:
				if original_music_volume == 0.0:
					original_music_volume = player.volume_db
				player.volume_db = original_music_volume + db_change

func _on_resume_pressed():
	toggle_pause()

func _on_options_pressed():
	pause_panel.visible = false
	options_panel.visible = true

func _on_back_pressed():
	options_panel.visible = false
	pause_panel.visible = true

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main_Menu.tscn")

func _on_volume_changed(value: float):
	update_volume_label()
	var volume_db = lerp(-80.0, 0.0, value / 10.0)
	var audio_players = get_tree().get_nodes_in_group("game_audio")
	for player in audio_players:
		if player is AudioStreamPlayer or player is AudioStreamPlayer2D:
			player.volume_db = volume_db

func update_volume_label():
	volume_label.text = str(int(volume_slider.value))
