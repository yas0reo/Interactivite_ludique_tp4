extends CharacterBody2D

@export var max_health := 50
@export var attack_damage := 15
@export var walk_speed := 70.0
@export var chase_speed := 90.0
@export var detection_range := 300.0
@export var attack_range := 80.0
@export var stun_duration := 0.5
@export var attack_cooldown := 1.0

var health: int
var is_moving_left := true
var is_stunned := false
var is_attacking := false
var is_dead := false

var player: CharacterBody2D
var direction_change_timer := 0.0
var next_direction_change := 5.0

@onready var anim = $AnimatedSprite2D
@onready var raycast = $RayCast2D
@onready var direction_timer = $DirectionTimer
@onready var hitbox = $Hitbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D

var hitbox_base_x := 0.0

func _ready():
	add_to_group("enemies")
	health = max_health
	anim.play("Walk")
	if hitbox_collision:
		hitbox_base_x = abs(hitbox_collision.position.x)
		hitbox_collision.position.y = 0.0
		var shape = hitbox_collision.shape as CircleShape2D
		if shape:
			shape.radius = 30.0
	
	randomize()
	next_direction_change = randf_range(5.0, 8.0)
	direction_timer.wait_time = next_direction_change
	direction_timer.start()

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	else:
		velocity.y = 0
	

	if hitbox_collision:
		if is_moving_left:
			hitbox_collision.position.x = -hitbox_base_x
		else:
			hitbox_collision.position.x = hitbox_base_x
	

	if is_stunned or is_attacking:
		velocity.x = 0
		move_and_slide()
		return
	player = Global.playerBody
	if player and is_instance_valid(player):
		var distance = position.distance_to(player.position)
		
		if distance <= attack_range:
			attack_player()
		elif distance <= detection_range:
			chase_player()
		else:
			patrol_movement()
	else:
		patrol_movement()
	
	anim.flip_h = is_moving_left
	
	if is_moving_left:
		raycast.position.x = -17
	else:
		raycast.position.x = 17
	
	move_and_slide()

func patrol_movement():
	if not anim.animation == "Walk":
		anim.play("Walk")
	
	if is_moving_left:
		velocity.x = -walk_speed
	else:
		velocity.x = walk_speed

	detect_turn_around()

func chase_player():
	if not anim.animation == "Walk":
		anim.play("Walk")
	
	var direction_to_player = sign(player.position.x - position.x)
	
	if direction_to_player < 0:
		is_moving_left = true
		velocity.x = -chase_speed
	else:
		is_moving_left = false
		velocity.x = chase_speed
	
	detect_turn_around()

func detect_turn_around():
	if is_on_floor() and not raycast.is_colliding():
		is_moving_left = !is_moving_left

func attack_player():
	if is_attacking or is_stunned:
		return
	
	if player and is_instance_valid(player):
		var direction_to_player = sign(player.position.x - position.x)
		is_moving_left = direction_to_player < 0
	
	is_attacking = true
	velocity.x = 0
	
	anim.play("Attack")

	await get_tree().create_timer(0.3).timeout
	if not is_dead and is_attacking:
		deal_damage_to_player()
	
	await get_tree().create_timer(0.3).timeout
	if not is_dead and is_attacking:
		deal_damage_to_player()

	await get_tree().create_timer(1.0).timeout
	
	if not is_dead:
		is_attacking = false
		anim.play("Walk")

func deal_damage_to_player():
	if not player or not is_instance_valid(player) or not hitbox:
		return
	
	var bodies_in_hitbox = hitbox.get_overlapping_bodies()
	
	if player in bodies_in_hitbox:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			print("Slime dealt ", attack_damage, " damage to player")

func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	print("Slime took ", amount, " damage. Health: ", health)
	
	if health <= 0:
		die()
		return
	apply_stun()

func apply_stun():
	if is_stunned:
		return
	
	is_stunned = true
	is_attacking = false 
	velocity.x = 0
	

	if anim.sprite_frames.has_animation("Stun"):
		anim.play("Stun")
	var original_modulate = anim.modulate
	anim.modulate = Color(1, 0.4, 0.4)
	
	await get_tree().create_timer(stun_duration).timeout
	
	if not is_dead:
		is_stunned = false
		anim.modulate = original_modulate
		anim.play("Walk")

func die():
	is_dead = true
	is_attacking = false
	is_stunned = false
	velocity = Vector2.ZERO
	
	anim.play("Death")
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if hitbox_collision:
		hitbox_collision.disabled = true
	
	await anim.animation_finished
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	queue_free()

func _on_direction_timer_timeout():
	if not is_stunned and not is_attacking and not is_dead:
		var player_ref = Global.playerBody
		if not player_ref or not is_instance_valid(player_ref):
			is_moving_left = !is_moving_left
		else:
			var distance = position.distance_to(player_ref.position)
			if distance > detection_range:
				is_moving_left = !is_moving_left
	
	next_direction_change = randf_range(5.0, 8.0)
	direction_timer.wait_time = next_direction_change
	direction_timer.start()
