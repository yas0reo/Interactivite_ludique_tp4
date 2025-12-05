extends Control

@onready var title_label = $CenterContainer/MenuContainer/TitleLabel
@onready var menu_buttons = $CenterContainer/MenuContainer/ButtonContainer
@onready var options_panel = $OptionsPanel
@onready var mode_selection_panel = $ModeSelectionPanel
@onready var story_mode_panel = $StoryModePanel
@onready var fade_overlay = $FadeOverlay
@onready var volume_slider = $OptionsPanel/MarginContainer/VBoxContainer/VolumeControl/VolumeSlider
@onready var volume_label = $OptionsPanel/MarginContainer/VBoxContainer/VolumeControl/VolumeValue
@onready var controls_container = $OptionsPanel/MarginContainer/VBoxContainer/ScrollContainer/ControlsContainer
@onready var resume_button = $StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton

var intro_complete := false
var awaiting_input := false
var current_action := ""
var current_button: Button = null

# Default key mappings
var key_mappings := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_W,
	"run": KEY_SHIFT,
	"dash": KEY_L,
	"attack_1": KEY_J,
	"attack_2": KEY_K
}

var action_labels := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"run": "Run",
	"dash": "Dash",
	"attack_1": "Attack 1",
	"attack_2": "Attack 2"
}

func _ready():
	title_label.modulate.a = 0
	for button in menu_buttons.get_children():
		button.modulate.a = 0
	options_panel.visible = false
	mode_selection_panel.visible = false
	story_mode_panel.visible = false
	fade_overlay.modulate.a = 1.0
	volume_slider.value = 10
	update_volume_label()
	
	# Check if save game exists
	check_save_game_exists()
	
	# Connect main menu buttons
	$CenterContainer/MenuContainer/ButtonContainer/StartButton.pressed.connect(_on_start_pressed)
	$CenterContainer/MenuContainer/ButtonContainer/OptionsButton.pressed.connect(_on_options_pressed)
	$CenterContainer/MenuContainer/ButtonContainer/ExitButton.pressed.connect(_on_exit_pressed)
	
	# Connect options panel buttons
	$OptionsPanel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	# Connect mode selection buttons
	if has_node("ModeSelectionPanel/MarginContainer/VBoxContainer/ButtonContainer/StoryButton"):
		$ModeSelectionPanel/MarginContainer/VBoxContainer/ButtonContainer/StoryButton.pressed.connect(_on_story_mode_pressed)
	if has_node("ModeSelectionPanel/MarginContainer/VBoxContainer/ButtonContainer/InfiniteButton"):
		$ModeSelectionPanel/MarginContainer/VBoxContainer/ButtonContainer/InfiniteButton.pressed.connect(_on_infinite_mode_pressed)
	if has_node("ModeSelectionPanel/MarginContainer/VBoxContainer/BackButton"):
		$ModeSelectionPanel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_mode_back_pressed)
	
	# Connect story mode selection buttons
	if has_node("StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/NewGameButton"):
		$StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	if has_node("StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton"):
		$StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton.pressed.connect(_on_resume_game_pressed)
	if has_node("StoryModePanel/MarginContainer/VBoxContainer/BackButton"):
		$StoryModePanel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_story_back_pressed)
	
	load_key_mappings()
	setup_control_buttons()
	play_intro_sequence()

func _input(event):
	if awaiting_input and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_key_rebind()
			return
		
		# Check if key is already assigned
		for action in key_mappings:
			if key_mappings[action] == event.keycode and action != current_action:
				print("Key already assigned to: ", action)
				cancel_key_rebind()
				return
		
		# Assign new key
		key_mappings[current_action] = event.keycode
		save_key_mappings()
		update_control_button(current_action)
		
		if current_button:
			current_button.text = OS.get_keycode_string(event.keycode)
			current_button.disabled = false
		
		awaiting_input = false
		current_action = ""
		current_button = null
		get_viewport().set_input_as_handled()

func setup_control_buttons():
	for action in action_labels:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		
		var label = Label.new()
		label.text = action_labels[action]
		label.custom_minimum_size = Vector2(150, 0)
		label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(label)
		
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 40)
		button.text = OS.get_keycode_string(key_mappings[action])
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_rebind_key.bind(action, button))
		hbox.add_child(button)
		
		controls_container.add_child(hbox)

func _on_rebind_key(action: String, button: Button):
	if awaiting_input:
		return
	
	awaiting_input = true
	current_action = action
	current_button = button
	button.text = "Press any key..."
	button.disabled = true

func cancel_key_rebind():
	if current_button:
		current_button.text = OS.get_keycode_string(key_mappings[current_action])
		current_button.disabled = false
	awaiting_input = false
	current_action = ""
	current_button = null

func update_control_button(action: String):
	var index = action_labels.keys().find(action)
	if index >= 0 and index < controls_container.get_child_count():
		var hbox = controls_container.get_child(index)
		var button = hbox.get_child(1) as Button
		if button:
			button.text = OS.get_keycode_string(key_mappings[action])

func save_key_mappings():
	var config = ConfigFile.new()
	for action in key_mappings:
		config.set_value("controls", action, key_mappings[action])
	config.save("user://key_mappings.cfg")

func load_key_mappings():
	var config = ConfigFile.new()
	var err = config.load("user://key_mappings.cfg")
	if err == OK:
		for action in key_mappings:
			if config.has_section_key("controls", action):
				key_mappings[action] = config.get_value("controls", action)

func check_save_game_exists():
	if not has_node("StoryModePanel/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton"):
		return
	
	var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if save_file:
		resume_button.disabled = false
		save_file.close()
	else:
		resume_button.disabled = true

func play_intro_sequence():
	var fade_in = create_tween()
	fade_in.tween_property(fade_overlay, "modulate:a", 0.0, 1.5)
	await fade_in.finished
	await get_tree().create_timer(0.5).timeout
	
	title_label.scale = Vector2(1.2, 1.2)
	var title_tween = create_tween()
	title_tween.set_parallel(true)
	title_tween.set_ease(Tween.EASE_OUT)
	title_tween.set_trans(Tween.TRANS_CUBIC)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 2.0)
	title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.5)
	await title_tween.finished
	await get_tree().create_timer(0.5).timeout
	
	var buttons = menu_buttons.get_children()
	for button in buttons:
		if button is Button:
			var button_tween = create_tween()
			button_tween.set_ease(Tween.EASE_OUT)
			button_tween.tween_property(button, "modulate:a", 1.0, 0.5)
			await get_tree().create_timer(0.2).timeout
	
	intro_complete = true
	print("Intro complete!")

func _on_start_pressed():
	if not intro_complete:
		return
	set_buttons_disabled(true)
	
	var fade_menu = create_tween()
	fade_menu.set_parallel(true)
	for button in menu_buttons.get_children():
		fade_menu.tween_property(button, "modulate:a", 0.0, 0.3)
	fade_menu.tween_property(title_label, "modulate:a", 0.3, 0.3)
	await fade_menu.finished
	
	mode_selection_panel.modulate.a = 0
	mode_selection_panel.visible = true
	var fade_mode = create_tween()
	fade_mode.tween_property(mode_selection_panel, "modulate:a", 1.0, 0.3)

func _on_story_mode_pressed():
	var fade_mode = create_tween()
	fade_mode.tween_property(mode_selection_panel, "modulate:a", 0.0, 0.3)
	await fade_mode.finished
	
	story_mode_panel.modulate.a = 0
	story_mode_panel.visible = true
	var fade_story = create_tween()
	fade_story.tween_property(story_mode_panel, "modulate:a", 1.0, 0.3)

func _on_new_game_pressed():
	# Delete existing save if any
	if FileAccess.file_exists("user://savegame.save"):
		DirAccess.remove_absolute("user://savegame.save")
	
	var fade_out = create_tween()
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
	await fade_out.finished
	# TODO: Replace with your story mode scene
	get_tree().change_scene_to_file("res://Scenes/Tutorial_Level.tscn")

func _on_resume_game_pressed():
	var fade_out = create_tween()
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
	await fade_out.finished
	# TODO: Load the save game and change to appropriate scene
	# For now, just load the tutorial level
	get_tree().change_scene_to_file("res://Scenes/Tutorial_Level.tscn")

func _on_story_back_pressed():
	var fade_story = create_tween()
	fade_story.tween_property(story_mode_panel, "modulate:a", 0.0, 0.3)
	await fade_story.finished
	story_mode_panel.visible = false
	
	mode_selection_panel.modulate.a = 0
	mode_selection_panel.visible = true
	var fade_mode = create_tween()
	fade_mode.tween_property(mode_selection_panel, "modulate:a", 1.0, 0.3)

func _on_infinite_mode_pressed():
	var fade_out = create_tween()
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
	await fade_out.finished
	# TODO: Replace with your infinite mode scene
	# get_tree().change_scene_to_file("res://Scenes/Infinite_Mode.tscn")
	print("Infinite mode not yet implemented")

func _on_mode_back_pressed():
	var fade_mode = create_tween()
	fade_mode.tween_property(mode_selection_panel, "modulate:a", 0.0, 0.3)
	await fade_mode.finished
	mode_selection_panel.visible = false
	
	set_buttons_disabled(false)
	var fade_menu = create_tween()
	fade_menu.set_parallel(true)
	for button in menu_buttons.get_children():
		fade_menu.tween_property(button, "modulate:a", 1.0, 0.3)
	fade_menu.tween_property(title_label, "modulate:a", 1.0, 0.3)

func _on_options_pressed():
	if not intro_complete:
		return
	var fade_menu = create_tween()
	fade_menu.set_parallel(true)
	for button in menu_buttons.get_children():
		fade_menu.tween_property(button, "modulate:a", 0.0, 0.3)
	fade_menu.tween_property(title_label, "modulate:a", 0.3, 0.3)
	await fade_menu.finished
	
	options_panel.modulate.a = 0
	options_panel.visible = true
	var fade_options = create_tween()
	fade_options.tween_property(options_panel, "modulate:a", 1.0, 0.3)

func _on_back_pressed():
	var fade_options = create_tween()
	fade_options.tween_property(options_panel, "modulate:a", 0.0, 0.3)
	await fade_options.finished
	options_panel.visible = false
	
	var fade_menu = create_tween()
	fade_menu.set_parallel(true)
	for button in menu_buttons.get_children():
		fade_menu.tween_property(button, "modulate:a", 1.0, 0.3)
	fade_menu.tween_property(title_label, "modulate:a", 1.0, 0.3)

func _on_exit_pressed():
	if not intro_complete:
		return
	var fade_out = create_tween()
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 0.8)
	await fade_out.finished
	get_tree().quit()

func _on_volume_changed(value: float):
	update_volume_label()
	var volume_db = lerp(-80.0, 0.0, value / 10.0)
	var audio_players = get_tree().get_nodes_in_group("game_audio")
	for player in audio_players:
		if player is AudioStreamPlayer or player is AudioStreamPlayer2D:
			player.volume_db = volume_db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)

func update_volume_label():
	volume_label.text = str(int(volume_slider.value))

func set_buttons_disabled(disabled: bool):
	for button in menu_buttons.get_children():
		if button is Button:
			button.disabled = disabled
