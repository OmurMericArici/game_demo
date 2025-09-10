extends Camera2D

@export var target: Node2D
@export var smooth = 5.0
@export var vertical_ratio = 0.8

@export var border_thickness = 64.0
@export var border_margin = 0.0
@export var border_len_mul = 3.0

@export var max_offset = Vector2(10, 6)
@export var max_rot_deg = 2.5
@export var decay = 1.8

@export var enemy_scene: PackedScene
@export var spawn_parent: Node
@export var path_len_mul = 6.0
@export var path_offset_mul = 1.4

# --- Mesafe-bazlı otomatik spawn ayarları ---
@export var spawn_base_distance: float = 800.0   # başlangıçta her 800 px yukarıya bir spawn
@export var spawn_min_distance: float = 200.0    # zorluk tavanında her 200 px'e bir spawn
@export var progress_to_max: float = 3000.0      # bu kadar yükselince min mesafeye iner
@export var distance_jitter: float = 0.20        # eşikte ±% sapma

@export var border_layer: int = 8  # Project Settings > 2D Physics'te bu kata "BORDER" adını ver


var trauma = 0.0
var _base_offset = Vector2.ZERO
var screen_h

var _L: StaticBody2D
var _R: StaticBody2D
var _B: StaticBody2D

var _path2d: Path2D
var _pathfollow: PathFollow2D

# --- İç durum (mesafe-bazlı spawn) ---
var _prev_cam_y: float = 0.0
var _climbed_total: float = 0.0
var _since_last_spawn: float = 0.0

func _ready():
	screen_h = get_viewport_rect().size.y
	offset.y = (vertical_ratio - 0.5) * screen_h
	_base_offset = offset

	_L = _make_border("L")
	_R = _make_border("R")
	_B = _make_border("B")

	_path2d = Path2D.new()
	_path2d.name = "SpawnPath"
	add_child(_path2d)
	_path2d.curve = Curve2D.new()

	_pathfollow = PathFollow2D.new()
	_pathfollow.name = "SpawnPathFollow"
	_path2d.add_child(_pathfollow)
	_pathfollow.rotates = false
	_pathfollow.loop = false

	if get_viewport().has_signal("size_changed"):
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_changed"))

	_update_borders()
	_update_path()

	_prev_cam_y = global_position.y

func _physics_process(delta):
	if target and target.global_position.y - global_position.y < 0:
		global_position.y = lerp(global_position.y, target.global_position.y, smooth * delta)

func _process(delta):
	if trauma > 0.0:
		var p = trauma * trauma
		offset = _base_offset + Vector2(randf_range(-1, 1) * max_offset.x * p, randf_range(-1, 1) * max_offset.y * p)
		rotation_degrees = randf_range(-1, 1) * max_rot_deg * p
		trauma = max(trauma - decay * delta, 0.0)
	else:
		offset = offset.lerp(_base_offset, 10.0 * delta)
		rotation = lerp(rotation, 0.0, 10.0 * delta)

	_update_borders()
	_update_path()
	_update_spawn_by_camera_motion()

func _update_spawn_by_camera_motion() -> void:
	var cam_y = global_position.y
	var dy = cam_y - _prev_cam_y
	_prev_cam_y = cam_y

	# Sadece YUKARI hareket (dy < 0) sayılır; dururken ya da aşağı inerken spawn olmaz.
	if dy < 0.0:
		var climbed = -dy
		_climbed_total += climbed
		_since_last_spawn += climbed

		var threshold = _current_spawn_distance_threshold()
		if _since_last_spawn >= threshold:
			_since_last_spawn = 0.0
			spawn_enemy_on_path()

func _current_spawn_distance_threshold() -> float:
	# Toplam ilerlemeye göre eşik lineer azalır
	var t = clamp(_climbed_total / max(1.0, progress_to_max), 0.0, 1.0)
	var base = lerp(spawn_base_distance, spawn_min_distance, t)
	# Küçük bir jitter ile insanı yanıltma ve kümelenmeyi kırma
	if distance_jitter > 0.0:
		var j = clamp(distance_jitter, 0.0, 0.9)
		var f = randf_range(1.0 - j, 1.0 + j)
		return max(10.0, base * f)
	return max(10.0, base)

func add_trauma(a: float) -> void:
	trauma = clamp(trauma + a, 0.0, 1.0)

func _make_border(n: String) -> StaticBody2D:
	var sb = StaticBody2D.new()
	sb.name = "Border_" + n
	var border_bit = 1 << (border_layer - 1)  # 1-based → bit
	sb.collision_layer = border_bit
	sb.collision_mask = 0
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	sb.add_child(cs)
	add_child(sb)
	return sb

func _update_borders() -> void:
	var view = get_viewport_rect().size
	var ww = view.x * zoom.x
	var wh = view.y * zoom.y
	var hw = ww * 0.5
	var hh = wh * 0.5

	var tall = wh * border_len_mul
	var wide = ww * border_len_mul

	(_L.get_child(0) as CollisionShape2D).shape.size = Vector2(border_thickness, tall)
	(_R.get_child(0) as CollisionShape2D).shape.size = Vector2(border_thickness, tall)
	_L.global_position = Vector2(global_position.x - hw - border_margin - border_thickness * 0.5, global_position.y)
	_R.global_position = Vector2(global_position.x + hw + border_margin + border_thickness * 0.5, global_position.y)

	(_B.get_child(0) as CollisionShape2D).shape.size = Vector2(wide, border_thickness)
	_B.global_position = Vector2(global_position.x, global_position.y + hh + border_margin + border_thickness * 0.5 + offset.y)

func _on_viewport_changed():
	_update_borders()
	_update_path()

func _update_path():
	if _path2d == null or _path2d.curve == null:
		return

	var view = get_viewport_rect().size
	var ww = view.x * zoom.x
	var wh = view.y * zoom.y
	var hw = ww * 0.5
	var hh = wh * 0.5

	# Path: ekranın üstünde yatay çizgi, sol/sağ viewport'u aşmaz
	var left_x = -hw
	var right_x = hw
	var y_above = -hh - wh * path_offset_mul

	var curve = _path2d.curve
	curve.clear_points()
	curve.add_point(Vector2(left_x, y_above))
	curve.add_point(Vector2(right_x, y_above))

	_path2d.position = Vector2.ZERO
	_path2d.global_position = global_position

func spawn_enemy_on_path():
	if enemy_scene == null:
		return
	if _path2d == null or _path2d.curve == null or _path2d.curve.get_point_count() < 2:
		return
	if _pathfollow == null:
		return

	_pathfollow.progress_ratio = randf()
	var enemy = enemy_scene.instantiate()
	var world_pos = _pathfollow.global_position

	if spawn_parent != null:
		spawn_parent.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)

	if "global_position" in enemy:
		enemy.global_position = world_pos
