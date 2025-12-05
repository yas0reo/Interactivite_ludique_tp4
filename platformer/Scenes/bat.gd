extends CharacterBody2D

@export var speed := 100.0
@export var detection_range := 350.0
@export var attack_range := 60.0
@export var attack_damage := 15 
@export var max_health := 30
@export var float_amplitude := 10.0
@export var float_speed := 2.0
@export var knockback_force := 200.0
@export var stun_duration := 0.6
@export var attack_cooldown := 1.0

var health: int
var player: CharacterBody2D
var direction := Vector2(1, 0)
var can_attack := true
var is_dead := false
var is_hurt := false
var is_stunned := false
var attack_timer := 0.1

var float_time := 0.0
var patrol_time := 0.0
var direction_change_timer := 0.0
var next_direction_change := 3.0

@onready var anim = $AnimatedSprite2D
@onready var hitbox = $Hitbox

func _ready():
	add_to_group("enemies")
	health = max_health
	anim.play("Fly")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	randomize()
	direction.x = 1 if randf() > 0.5 else -1
	next_direction_change = randf_range(2.0, 4.0)

func _physics_process(delta):
	if is_dead:
		return

	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Stun
	if is_stunned:
		move_and_slide()
		velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
		return

	# Déplacement
	float_time += delta
	patrol_time += delta
	direction_change_timer += delta

	# Attaque le joueur
	player = Global.playerBody
	
	if not player or not is_instance_valid(player):
		_idle_movement(delta)
	else:
		var distance = position.distance_to(player.position)

		if distance <= attack_range and can_attack:
			attack_player()
		elif distance <= detection_range:
			chase_player(delta)
		else:
			_idle_movement(delta)

	move_and_slide()

func _idle_movement(delta):
	if not is_hurt and not is_stunned:
		anim.play("Fly")
	
	# Changer de direction pour eviter les murs
	if direction_change_timer >= next_direction_change:
		direction.x *= -1
		anim.flip_h = direction.x < 0
		direction_change_timer = 0.0
		next_direction_change = randf_range(2.0, 4.0)
	
	# Change de direction quand elle tappe un mur
	if is_on_wall():
		direction.x *= -1
		anim.flip_h = direction.x < 0
		direction_change_timer = 0.0
		next_direction_change = randf_range(2.0, 4.0)
		position.x += direction.x * 5
	
	var float_offset = sin(float_time * float_speed) * float_amplitude
	velocity = Vector2(direction.x * speed, float_offset)
	
func chase_player(delta):
	if not is_hurt and not is_stunned:
		anim.play("Attack")
	
	var dir = (player.position - position).normalized()
	dir.y += sin(float_time * float_speed) * 0.1
	velocity = dir.normalized() * speed
	
	anim.flip_h = dir.x < 0
	
func attack_player():
	if is_stunned or not can_attack:
		return

	can_attack = false
	attack_timer = attack_cooldown 
	anim.play("Attack")
	velocity = Vector2.ZERO
	
	# Degats Attaque
	if player and is_instance_valid(player):
		if position.distance_to(player.position) <= attack_range:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
				print("Bat dealt ", attack_damage, " damage to player")

func _on_hitbox_body_entered(body):
	if body == Global.playerBody and can_attack and not is_dead and not is_stunned:
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			print("Bat contact damage: ", attack_damage)
			can_attack = false
			attack_timer = attack_cooldown

func take_damage(amount: int, attack_type: String=""):
	if is_dead or is_stunned:
		return

	health -= amount
	print("Bat took ", amount, " damage. Health: ", health)

	if health <= 0:
		die()
		return

	apply_hurt(attack_type)

func apply_hurt(attack_type: String=""):
	if is_dead:
		return

	is_hurt = true
	is_stunned = true
	can_attack = false
	attack_timer = 0.0

	if anim.sprite_frames.has_animation("Hurt"):
		anim.play("Hurt")
	
	if player and is_instance_valid(player):
		var knockback_dir = (position - player.position).normalized()
		velocity = knockback_dir * knockback_force
	else:
		velocity = Vector2(-direction.x * knockback_force, -50)

	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0.4, 0.4), 0.1)
	
	await get_tree().create_timer(stun_duration).timeout
	
	if not is_dead:
		var tween2 = create_tween()
		tween2.tween_property(anim, "modulate", Color(1, 1, 1), 0.2)
		
		is_stunned = false
		is_hurt = false
		can_attack = true
		anim.play("Fly")

# Mort

func die():
	is_dead = true
	can_attack = false
	is_stunned = false
	velocity = Vector2.ZERO
	
	if anim.sprite_frames.has_animation("Death"):
		anim.play("Death")
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	queue_free()
