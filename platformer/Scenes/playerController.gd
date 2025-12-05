extends CharacterBody2D

# --- MOVEMENT ---
@export var walk_speed := 150.0
@export var run_speed := 300.0
@export_range(0, 1) var acceleration := 0.1
@export_range(0, 1) var deceleration := 0.1

# --- JUMP ---
@export_range(0, 1) var decelerate_on_jump_release := 0.5
@export var jump_force := -500.0

# --- DASH ---
@export var dash_speed := 700.0
@export var dash_max_distance := 60.0
@export var dash_cooldown := 0.5
@export var dash_curve : Curve

# --- HEALTH ---
@export var heart_value := 50
@export var heart_count := 5
@export var killzone_y := 1200.0
@export var respawn_position := Vector2(100, 100)

var max_health : int
var health : int
var alive := true
var hearts_list : Array[TextureRect] = []
var fall_damage_cooldown := false

# --- ATTACKS ---
@export var attack1_damage := 10
@export var attack2_damage := 15
@export var attack_cooldown := 0.3
var can_attack := true
var is_attacking := false
var attack_timer := 0.0

# --- NODES (onready) ---
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/AttackArea
@onready var attack_sound1: AudioStreamPlayer2D = $Attack1
@onready var attack_sound2: AudioStreamPlayer2D = $Attack2

# --- AUDIO / ANIM ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var low_health_sound: AudioStreamPlayer2D = $LowHealth

# --- DASH STATE ---
var is_dashing := false
var can_dash := true
var dash_start_position := 0.0
var dash_direction := 0.0

# --- Internal ---
var attack_area_base_x := 0.0

func _ready():
	Global.playerBody = self

	max_health = heart_value * heart_count
	health = max_health

	if $health_bar and $health_bar.has_node("HBoxContainer"):
		var hearts_parent = $health_bar/HBoxContainer
		for child in hearts_parent.get_children():
			hearts_list.append(child)
	update_heart_display()

	if attack_collision:
		attack_area_base_x = attack_collision.position.x
		attack_collision.disabled = true

func _physics_process(delta: float) -> void:

	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false

	if attack_collision:
		if animated_sprite and animated_sprite.flip_h:
			attack_collision.position.x = -attack_area_base_x
		else:
			attack_collision.position.x = attack_area_base_x

	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

	# --- KILLZONE CHECK ---
	if position.y > killzone_y and alive and not fall_damage_cooldown:
		fall_damage_cooldown = true
		take_damage(heart_value)

		if health > 0:
			respawn()
		else:
			death()

		get_tree().create_timer(1.0).timeout.connect(func(): fall_damage_cooldown = false)

	# --- ATTACK INPUT ---
	if can_attack and not is_attacking:
		if Input.is_action_just_pressed("Attack1"):
			perform_attack(1)
		elif Input.is_action_just_pressed("Attack2"):
			perform_attack(2)

	# --- DASH → JUMP COMBO ---
	if not is_attacking or attack_timer < 0.2:  # Allow jump during most of attack
		if Input.is_action_just_pressed("Jump"):
			if is_dashing:
				stop_dash()
				velocity.y = jump_force
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Jump"):
					animated_sprite.play("Jump")
				is_attacking = false
				attack_timer = 0

			elif is_on_floor() or is_on_wall():
				velocity.y = jump_force
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Jump"):
					animated_sprite.play("Jump")

	# --- SHORTER JUMP ---
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release

	# --- RUN/WALK SPEED ---
	var is_running := Input.is_action_pressed("Run")
	var target_speed := (run_speed if is_running else walk_speed)

	# --- HORIZONTAL MOVEMENT ---
	var direction := Input.get_axis("Left", "Right")

	# Allow movement during attack, but reduce speed slightly
	var movement_multiplier = 0.7 if is_attacking else 1.0
	
	if not is_dashing:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * target_speed * movement_multiplier, target_speed * acceleration)
			# Only flip sprite if not attacking
			if not is_attacking:
				animated_sprite.flip_h = direction < 0
			# Play movement animation only if not attacking
			if is_on_floor() and not is_attacking:
				var anim_name := "Run" if is_running else "Walk"
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
					animated_sprite.play(anim_name)
		else:
			velocity.x = move_toward(velocity.x, 0, walk_speed * deceleration)
			# Play idle only if not attacking
			if is_on_floor() and not is_attacking:
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Idle"):
					animated_sprite.play("Idle")

	# --- DASH ---
	if not is_attacking or attack_timer < 0.1:  # Allow dash near end of attack
		if Input.is_action_just_pressed("Dash") and direction != 0 and can_dash and not is_dashing:
			start_dash(direction)
			is_attacking = false
			attack_timer = 0

	if is_dashing:
		var current_distance := absf(position.x - dash_start_position)
		if current_distance >= dash_max_distance or is_on_wall():
			stop_dash()
		else:
			var t = clamp(current_distance / dash_max_distance, 0.0, 1.0)
			var dash_factor := dash_curve.sample(t) if dash_curve else 1.0
			velocity.x = dash_direction * dash_speed * dash_factor
			velocity.y = 0

	# --- FALLING ANIMATION ---
	if not is_on_floor() and velocity.y > 0 and not is_dashing and not is_attacking:
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Fall"):
			animated_sprite.play("Fall")

	move_and_slide()


# --- ATTACK FUNCTIONS ---
func perform_attack(type: int) -> void:
	can_attack = false
	is_attacking = true
	
	var damage := 0
	var attack_sound: AudioStreamPlayer2D = null
	var anim_name := ""
	var attack_duration := 0.4  

	match type:
		1:
			damage = attack1_damage
			attack_sound = attack_sound1
			anim_name = "Attack1"
			attack_duration = 0.4
		2:
			damage = attack2_damage
			attack_sound = attack_sound2
			anim_name = "Attack2"
			attack_duration = 0.5

	attack_timer = attack_duration

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


	if attack_sound:
		attack_sound.play()

	if attack_collision:
		attack_collision.disabled = false
	await get_tree().create_timer(0.15).timeout
	apply_attack_damage(damage)
	await get_tree().create_timer(attack_duration - 0.15).timeout
	if attack_collision:
		attack_collision.disabled = true
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func apply_attack_damage(damage: int) -> void:
	if not attack_area:
		return
	
	for body in attack_area.get_overlapping_bodies():
		if body and body != self and body.has_method("take_damage"):
			body.take_damage(damage)
			print("Player dealt ", damage, " damage to ", body.name)


# --- DASH FUNCTIONS ---
func start_dash(direction: float) -> void:
	is_dashing = true
	can_dash = false
	dash_start_position = position.x
	dash_direction = direction
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Dashing"):
		animated_sprite.play("Dashing")
	get_tree().create_timer(dash_cooldown).timeout.connect(_on_dash_cooldown_finished)


func stop_dash() -> void:
	is_dashing = false


func _on_dash_cooldown_finished() -> void:
	can_dash = true


# --- HEALTH SYSTEM ---
func take_damage(amount: int):
	if not alive:
		return

	health = max(health - amount, 0)
	print("Player took ", amount, " damage. Health: ", health, "/", max_health)
	update_heart_display()

	if health <= heart_value and health > 0:
		if low_health_sound:
			low_health_sound.play()

	if health <= 0:
		alive = false
		call_deferred("death")


func update_heart_display():
	var hearts_to_show = int(ceil(float(health) / float(heart_value)))
	for i in range(hearts_list.size()):
		hearts_list[i].visible = i < hearts_to_show


func respawn():
	position = respawn_position
	velocity = Vector2.ZERO
	alive = true
	set_process(true)
	set_physics_process(true)
	update_heart_display()


# --- DEATH SEQUENCE ---
func death():
	print_debug("called death")
	alive = false
	is_dashing = false
	can_dash = false
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(0.2).timeout
	call_deferred("_go_to_death_screen")
	
func _go_to_death_screen():
	get_tree().change_scene_to_file("res://Scenes/death_screen.tscn")
