extends Node2D

@export var sway_freq_base := 4.0      # temel sallanma frekansı
@export var sway_angle_deg := 6.0      # maksimum sağ-sol açı
@export var bob_px := 1.5              # hafif aşağı-yukarı
@export var speed_influence := 1.0     # hıza bağlı kuvvet (0..1)

var _phase = 0.0

func _process(delta: float) -> void:
	var parent = get_parent()
	var v = parent.velocity if parent and parent.has_method("get_velocity") == false else Vector2.ZERO
	if parent and "velocity" in parent:
		v = parent.velocity

	var sp = v.length()
	var max_sp = parent.max_speed if parent and "max_speed" in parent else 300.0
	var k = clamp(sp / max_sp, 0.0, 1.0)

	var freq = lerp(0.0, sway_freq_base, k)
	if freq > 0.0:
		_phase += freq * TAU * delta
		
	var s = 0
	if k > 0:
		s = sin(_phase)
		rotation_degrees = s * sway_angle_deg * (lerp(0.3, 1.0, speed_influence * k))
		position.y = s * bob_px
	else:
		rotation_degrees = 0
	
