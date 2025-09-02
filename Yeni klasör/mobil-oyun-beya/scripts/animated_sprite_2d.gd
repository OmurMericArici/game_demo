extends Node2D

@export var sway_freq_base = 4.0
@export var sway_angle_deg = 6.0
@export var bob_px = 1.5
@export var speed_influence = 1.0

@export var stop_speed = 5.0       # bunun altı "duruyor"
@export var return_speed = 12.0    # sıfıra dönüş hızı
@export var snap_deg = 0.02        # bu açıdan küçükse 0'a sabitle
@export var snap_px = 0.02         # bu pikselden küçükse 0'a sabitle

var _phase = 0.0

func _process(delta: float) -> void:
	var p = get_parent()
	if p == null or not (p is CharacterBody2D):
		# güvenli fallback
		rotation_degrees = lerp(rotation_degrees, 0.0, return_speed * delta)
		position.y = lerp(position.y, 0.0, return_speed * delta)
		_phase = 0.0
		return

	var v: Vector2 = (p as CharacterBody2D).velocity
	var sp = v.length()

	# max_speed'i güvenli al (yoksa 300.0 kullan)
	var max_sp_val = p.get("max_speed")
	var max_sp: float = 300.0
	if max_sp_val != null:
		max_sp = float(max_sp_val)

	var k = clamp(sp / max_sp, 0.0, 1.0)

	if sp > stop_speed:
		var freq = lerp(0.0, sway_freq_base, k)
		if freq > 0.0:
			_phase += freq * TAU * delta

		var s = sin(_phase)
		rotation_degrees = s * sway_angle_deg * lerp(0.3, 1.0, speed_influence * k)
		position.y = s * bob_px
	else:
		# duruşta sıfıra çek + küçük değerleri yapıştır
		rotation_degrees = lerp(rotation_degrees, 0.0, return_speed * delta)
		position.y = lerp(position.y, 0.0, return_speed * delta)

		if abs(rotation_degrees) < snap_deg:
			rotation_degrees = 0.0
		if abs(position.y) < snap_px:
			position.y = 0.0

		_phase = 0.0
