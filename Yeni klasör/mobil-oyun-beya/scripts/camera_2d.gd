extends Camera2D

@export var target: Node2D
@export var smooth = 5.0
@export var vertical_ratio = 0.80  # 0.0 = üst, 1.0 = alt

# ---- Shake (trauma) ayarları ----
@export var max_offset := Vector2(10, 6)  # px
@export var max_rot_deg := 2.5            # derece
@export var decay := 1.8                  # sönüm (büyük = çabuk biter)

var trauma = 0.0
var _base_offset := Vector2.ZERO

func _ready():
	# Ekran yüksekliğine göre baz ofseti ayarla
	var screen_h = get_viewport_rect().size.y
	offset.y = (vertical_ratio - 0.5) * screen_h
	_base_offset = offset  # shake bu bazın etrafında çalışacak

func _physics_process(delta):
	if not target:
		return
	# Sadece yukarı doğru takip (player kamera merkezinin üstüne çıkarsa)
	if target.global_position.y < global_position.y:
		global_position.y = lerp(global_position.y, target.global_position.y, smooth * delta)

func _process(delta):
	# Kamera shake (trauma) uygula
	if trauma > 0.0:
		var p = trauma * trauma  # şiddeti dramatikleştir
		var shake_off = Vector2(
			randf_range(-1.0, 1.0) * max_offset.x * p,
			randf_range(-1.0, 1.0) * max_offset.y * p
		)
		offset = _base_offset + shake_off
		rotation_degrees = randf_range(-1.0, 1.0) * max_rot_deg * p
		trauma = max(trauma - decay * delta, 0.0)
	else:
		# Baz ofsete ve 0 dereceye yumuşak dönüş
		offset = offset.lerp(_base_offset, 10.0 * delta)
		rotation = lerp(rotation, 0.0, 10.0 * delta)

# Dışarıdan çağır: çarpışma vb. olduğunda sarsıntı ekle
func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)


func _on_character_body_2d_hit_shake(intensity: float) -> void:
	pass # Replace with function body.
