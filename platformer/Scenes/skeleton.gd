extends CharacterBody2D

# --- STATS ---
@export var max_health := 75
@export var attack_damage := 10
@export var move_speed := 100.0
@export var detection_range := 350.0
@export var attack_range := 80.0
@export var attack_delay := 0.5
@export var stun_duration := 0.5  # Time skeleton is stunned when hit

var health : int
var alive := true
var is_hurt := false
var can_attack := true
var is_attacking := false
var player_in_detection_range := false
var player_in_attack_range := false
var player_reference = null
var is_stunned := false  # Track stun state

# --- WANDERING ---
var wander_direction := 0.0
var is_wandering := false
var wander_change_time := 0.0
var next_wander_change := 3.0  # Time until next wander direction change

# --- NODES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape
@onready var wander_timer: Timer = $WanderTimer

# --- BASE POSITIONS ---
var attack_shape_base_x := 0.0

func _ready():
	health = max_health
	add_to_group("enemies")
	
	# Store base position for attack area
	if attack_shape:
		attack_shape_base_x = attack_shape.position.x
		attack_shape.disabled = true
	
	# Connect signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	if wander_timer:
		wander_timer.timeout.connect(_on_wander_timer_timeout)
	
	# Start with idle animation
	if animated_sprite:
		animated_sprite.play("idle")
	
	# Start wandering
	randomize()
	_start_random_wander()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	# Apply gravity always
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	
	# Flip attack area to match facing direction
	if attack_shape:
		if animated_sprite and animated_sprite.flip_h:
			attack_shape.position.x = -attack_shape_base_x
		else:
			attack_shape.position.x = attack_shape_base_x
	
	# Stop movement if hurt or attacking
	if is_hurt or is_attacking:
		velocity.x = 0
		move_and_slide()
		return
	
	# Update wander timer
	wander_change_time += delta
	
	# AI behavior
	if player_in_detection_range and player_reference and player_reference.alive:
		# Attack if in range
		if player_in_attack_range and can_attack and not is_attacking:
			_perform_attack()
		elif not is_attacking:
			_chase_player()
	else:
		_wander()
	
	move_and_slide()

# --- WANDERING ---
func _start_random_wander():
	var rand = randf()
	if rand < 0.4:
		wander_direction = -1.0  # Move left
		is_wandering = true
	elif rand < 0.8:
		wander_direction = 1.0   # Move right
		is_wandering = true
	else:
		wander_direction = 0.0   # Stand still
		is_wandering = false
	
	# Set random time until next direction change
	wander_change_time = 0.0
	next_wander_change = randf_range(2.0, 5.0)

func _wander():
	# Check if it's time to change direction
	if wander_change_time >= next_wander_change:
		_start_random_wander()
	
	if is_wandering:
		velocity.x = wander_direction * move_speed
		if animated_sprite:
			animated_sprite.flip_h = wander_direction < 0
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.2)
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _on_wander_timer_timeout():
	# Timer as backup for wander changes
	if not player_in_detection_range:
		_start_random_wander()

# --- PLAYER DETECTION ---
func _chase_player():
	if not player_reference:
		return
	
	var direction = sign(player_reference.global_position.x - global_position.x)
	velocity.x = direction * move_speed
	
	if animated_sprite:
		animated_sprite.flip_h = direction < 0
		if not is_attacking and animated_sprite.animation != "walk":
			animated_sprite.play("walk")

func _on_detection_area_body_entered(body):
	if body.name == "Player" and body.has_method("take_damage"):
		player_in_detection_range = true
		player_reference = body

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		player_in_detection_range = false
		player_reference = null
		_start_random_wander()

func _on_attack_area_body_entered(body):
	if body.name == "Player" and body.has_method("take_damage"):
		player_in_attack_range = true

func _on_attack_area_body_exited(body):
	if body.name == "Player":
		player_in_attack_range = false

# --- ATTACK ---
func _perform_attack():
	can_attack = false
	is_attacking = true
	velocity.x = 0
	
	# Randomly choose attack animation
	var attack_type = randi() % 2 + 1
	var attack_anim = "attack1" if attack_type == 1 else "attack2"
	
	if animated_sprite:
		animated_sprite.play(attack_anim)
	
	# Enable attack collision
	if attack_shape:
		attack_shape.disabled = false
	
	# Wait for attack to land
	await get_tree().create_timer(attack_delay).timeout
	_apply_attack_damage()
	
	# Wait for animation to finish
	if animated_sprite:
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	# Disable attack collision
	if attack_shape:
		attack_shape.disabled = true
	
	is_attacking = false
	
	# Start cooldown
	await get_tree().create_timer(0.5).timeout
	can_attack = true

func _apply_attack_damage():
	if not attack_area or not player_reference:
		return
	
	for body in attack_area.get_overlapping_bodies():
		if body and body.name == "Player" and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			print("Skeleton dealt ", attack_damage, " damage to Player")

# --- DAMAGE ---
func take_damage(amount: int):
	if not alive or is_hurt:
		return
	
	health = max(health - amount, 0)
	print("Skeleton took ", amount, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		_die()
	else:
		_play_hurt_animation()

func _play_hurt_animation():
	is_hurt = true
	is_attacking = false  # Cancel any attack
	velocity.x = 0
	
	if animated_sprite:
		animated_sprite.play("hurt")
		# Apply red tint
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(1, 0.4, 0.4), 0.1)
	
	# Stun duration
	await get_tree().create_timer(stun_duration).timeout
	
	if alive and animated_sprite:
		# Remove red tint
		var tween2 = create_tween()
		tween2.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.2)
		
		is_hurt = false
		animated_sprite.play("idle")

# --- DEATH ---
func _die():
	alive = false
	is_attacking = false
	is_hurt = false
	velocity = Vector2.ZERO
	
	# Disable collision
	set_physics_process(false)
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)
	
	# Play death animation
	if animated_sprite:
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	
	# Remove from scene
	queue_free()
