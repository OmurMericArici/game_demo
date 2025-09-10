extends CharacterBody2D

@export var collision_threshold = 0.05   # hız eşiği: max_speed * threshold (shake için)
@export var max_speed: float = 500
@export var accel: float = 1500
@export var deaccel: float = 1200
@export var input_lerp_speed: float = 10.0
@export var turn_boost: float = 1.2
@export var bounce_strength: float = 0.6

# Shake (anti-spam)
@export var shake_min = 0.05
@export var shake_max = 0.9
@export var shake_min_interval = 0.15
@export var shake_min_angle_deg = 50.0

# Opsiyonel toz
@export var dust_node_path: NodePath

# State eşikleri
@export var walking_min_speed: float = 10.0     # yürüme için minimum hız
@export var running_ratio: float = 0.65         # running eşiği = max_speed * running_ratio

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var camera2d: Camera2D = get_node("../Camera2D") if has_node("../Camera2D") else null
@onready var dust: GPUParticles2D = get_node(dust_node_path) if dust_node_path != NodePath() and has_node(dust_node_path) else null

signal hit_shake(intensity: float)
signal bounce_dust(pos: Vector2, normal: Vector2)

# State değişim sinyalleri
signal state_changed(old_state: String, new_state: String)
signal entered_idle()
signal entered_walking()
signal entered_running()

var _input_raw: Vector2 = Vector2.ZERO
var _input_smooth: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0
var _did_shake_this_frame: bool = false

enum { STATE_IDLE, STATE_WALKING, STATE_RUNNING }
var _state = STATE_IDLE

func _physics_process(delta: float) -> void:
	_did_shake_this_frame = false

	# --- Girdi ve hız hedefi ---
	_input_raw = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	)
	if _input_raw.length() > 1.0:
		_input_raw = _input_raw.normalized()

	_input_smooth = _input_smooth.lerp(_input_raw, clamp(input_lerp_speed * delta, 0.0, 1.0))
	var target_velocity: Vector2 = _input_smooth * max_speed

	# --- İvme / yavaşlama ---
	if _input_smooth != Vector2.ZERO:
		var t = accel
		if velocity != Vector2.ZERO and sign(_input_smooth.x) != sign(velocity.x) and absf(_input_smooth.x) > 0.0:
			t *= turn_boost
		if velocity != Vector2.ZERO and sign(_input_smooth.y) != sign(velocity.y) and absf(_input_smooth.y) > 0.0:
			t *= turn_boost
		velocity = velocity.move_toward(target_velocity, t * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deaccel * delta)

	# --- Çarpışma ve efektler ---
	var collision = move_and_collide(velocity * delta)
	if collision:
		var speed = velocity.length()
		var thresh = max_speed * collision_threshold

		var n: Vector2 = collision.get_normal()
		var dir: Vector2 = (velocity / speed) if speed > 0.0 else Vector2.ZERO
		var head_on_dot = -dir.dot(n)
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

	# --- State güncelle ---
	var speed_now = velocity.length()
	_update_state_by_speed(speed_now)

	# --- Sprite ---
	if sprite:
		if speed_now > walking_min_speed:
			sprite.flip_h = velocity.x < 0.0
			if _state == STATE_RUNNING:
				if sprite.has_animation("run"):
					if not sprite.is_playing() or sprite.animation != "run":
						sprite.play("run")
				else:
					if not sprite.is_playing() or sprite.animation != "walk":
						sprite.play("walk")
			else:
				if not sprite.is_playing() or sprite.animation != "walk":
					sprite.play("walk")
		else:
			if not sprite.is_playing() or sprite.animation != "idle":
				sprite.play("idle")

# --- State yardımcıları ---

func _update_state_by_speed(s: float) -> void:
	var run_threshold = max_speed * running_ratio
	var new_state = _state

	if s <= walking_min_speed:
		new_state = STATE_IDLE
	elif s < run_threshold:
		new_state = STATE_WALKING
	else:
		new_state = STATE_RUNNING

	if new_state != _state:
		var old_name = _state_name(_state)
		_state = new_state
		var new_name = _state_name(_state)
		
		# --- Konsola yazdır ---
		print("State changed from %s to %s" % [old_name, new_name])
		
		emit_signal("state_changed", old_name, new_name)
		match _state:
			STATE_IDLE:
				emit_signal("entered_idle")
			STATE_WALKING:
				emit_signal("entered_walking")
			STATE_RUNNING:
				emit_signal("entered_running")
func _state_name(s: int) -> String:
	match s:
		STATE_IDLE: return "Idle"
		STATE_WALKING: return "Walking"
		STATE_RUNNING: return "Running"
		_: return "Unknown"
