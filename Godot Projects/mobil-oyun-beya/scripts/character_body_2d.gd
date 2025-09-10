extends CharacterBody2D

@export var collision_threshold = 0.05   # hız eşiği: max_speed * threshold
@export var max_speed: float = 500
@export var accel: float = 1500
@export var deaccel: float = 1200
@export var input_lerp_speed: float = 10.0
@export var turn_boost: float = 1.2
@export var bounce_strength: float = 0.6

# Shake (anti-spam)
@export var shake_min = 0.05
@export var shake_max = 0.9
@export var shake_min_interval = 0.15     # saniye
@export var shake_min_angle_deg = 50.0    # yana sürtünmeleri ele

# Opsiyonel toz
@export var dust_node_path: NodePath

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var camera2d: Camera2D = get_node("../Camera2D") if has_node("../Camera2D") else null
@onready var dust: GPUParticles2D = get_node(dust_node_path) if dust_node_path != NodePath() and has_node(dust_node_path) else null

signal hit_shake(intensity: float)
signal bounce_dust(pos: Vector2, normal: Vector2)

var _input_raw: Vector2 = Vector2.ZERO
var _input_smooth: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0
var _did_shake_this_frame: bool = false

func _physics_process(delta: float) -> void:
	_did_shake_this_frame = false

	_input_raw = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	)
	if _input_raw.length() > 1.0:
		_input_raw = _input_raw.normalized()

	_input_smooth = _input_smooth.lerp(_input_raw, clamp(input_lerp_speed * delta, 0.0, 1.0))
	var target_velocity: Vector2 = _input_smooth * max_speed

	if _input_smooth != Vector2.ZERO:
		var t = accel
		if velocity != Vector2.ZERO and sign(_input_smooth.x) != sign(velocity.x) and absf(_input_smooth.x) > 0.0:
			t *= turn_boost
		if velocity != Vector2.ZERO and sign(_input_smooth.y) != sign(velocity.y) and absf(_input_smooth.y) > 0.0:
			t *= turn_boost
		velocity = velocity.move_toward(target_velocity, t * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deaccel * delta)

	var collision = move_and_collide(velocity * delta)
	if collision:
		var speed = velocity.length()
		var thresh = max_speed * collision_threshold

		var n: Vector2 = collision.get_normal()
		var dir: Vector2 = (velocity / speed) if speed > 0.0 else Vector2.ZERO  # ← ternary fix
		var head_on_dot = -dir.dot(n)  # 1 = tam kafa kafaya
		var min_dot = cos(deg_to_rad(shake_min_angle_deg))

		var can_shake = (_shake_timer <= 0.0) and (not _did_shake_this_frame) and (speed > thresh) and (head_on_dot >= min_dot)

		if can_shake:
			var tval = clamp((speed - thresh) / max(1.0, (max_speed - thresh)), 0.0, 1.0)
			var intensity = lerp(shake_min, shake_max, tval)

			emit_signal("hit_shake", intensity)
			if camera2d and camera2d.has_method("add_trauma"):
				camera2d.add_trauma(intensity)

			emit_signal("bounce_dust", collision.get_position(), n)
			if dust:
				dust.global_position = collision.get_position() - n * 6.0
				dust.restart()
				dust.emitting = true

			_shake_timer = shake_min_interval
			_did_shake_this_frame = true

		velocity = velocity.bounce(n) * bounce_strength
		move_and_collide(velocity * delta)

	if _shake_timer > 0.0:
		_shake_timer -= delta
	

	
	if sprite:
		if velocity.length() > 10.0:
			sprite.flip_h = velocity.x < 0.0
			if not sprite.is_playing():
				sprite.play("walk")
		else:
			sprite.play("idle")
