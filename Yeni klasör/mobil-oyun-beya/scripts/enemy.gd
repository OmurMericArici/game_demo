# Enemy.gd
extends CharacterBody2D

@export var speed: float = 30.0
@export var target_group: StringName = "player"
@export var target_path: NodePath
@export_enum("random", "chase", "ambush", "inky", "clyde") var strategy: String = "random"

@export var ambush_ahead: float = 160.0
@export var clyde_radius: float = 160.0
@export var scatter_points: PackedVector2Array = []
@export var inky_partner_path: NodePath

@export var sprite_path: NodePath
@export var tint_strength: float = 1.0

var target: Node2D
var inky_partner: Node2D
var _chosen: String = "chase"

var _prev_target_pos: Vector2 = Vector2.ZERO
var _target_vel: Vector2 = Vector2.ZERO
var _vel_smooth: float = 0.15
var _my_scatter: Vector2 = Vector2.ZERO

var _sprite: Sprite2D
var _shader_mat: ShaderMaterial

const HUE_SHADER_CODE = """
shader_type canvas_item;
uniform vec4 target_color : source_color;
uniform float strength = 1.0;

vec3 rgb2hsv(vec3 c){
	float cmax = max(c.r, max(c.g, c.b));
	float cmin = min(c.r, min(c.g, c.b));
	float d = cmax - cmin;
	float h = 0.0;
	if (d > 1e-5) {
		if (cmax == c.r)      h = mod((c.g - c.b) / d, 6.0);
		else if (cmax == c.g) h = (c.b - c.r) / d + 2.0;
		else                   h = (c.r - c.g) / d + 4.0;
		h /= 6.0;
	}
	float s = (cmax <= 1e-5) ? 0.0 : (d / cmax);
	float v = cmax;
	return vec3(h, s, v);
}

vec3 hsv2rgb(vec3 c){
	float h = c.x * 6.0;
	float s = c.y;
	float v = c.z;
	int i = int(floor(h));
	float f = h - float(i);
	float p = v * (1.0 - s);
	float q = v * (1.0 - f * s);
	float t = v * (1.0 - (1.0 - f) * s);

	if (i == 0) return vec3(v, t, p);
	else if (i == 1) return vec3(q, v, p);
	else if (i == 2) return vec3(p, v, t);
	else if (i == 3) return vec3(p, q, v);
	else if (i == 4) return vec3(t, p, v);
	else             return vec3(v, p, q);
}

void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	vec3 target_hsv = rgb2hsv(target_color.rgb);

	vec3 tinted = hsv;
	tinted.x = target_hsv.x;
	tinted.y = mix(hsv.y, max(hsv.y, target_hsv.y), strength);
	tinted.z = hsv.z;

	vec3 rgb_tinted = hsv2rgb(tinted);
	vec3 out_rgb = mix(tex.rgb, rgb_tinted, strength);
	COLOR = vec4(out_rgb, tex.a);
}
"""

func _ready() -> void:
	if target == null and target_path != NodePath():
		target = get_node_or_null(target_path) as Node2D
	if target == null and String(target_group) != "":
		target = get_tree().get_first_node_in_group(target_group) as Node2D
	if inky_partner_path != NodePath():
		inky_partner = get_node_or_null(inky_partner_path) as Node2D

	if strategy == "random":
		var opts = ["chase", "ambush", "inky", "clyde"]
		_chosen = opts[randi() % opts.size()]
	else:
		_chosen = strategy

	if target:
		_prev_target_pos = target.global_position
	if _chosen == "clyde":
		_my_scatter = _pick_scatter_corner()

	_setup_tint_material()
	_apply_tint_for_strategy()

func set_target(n: Node2D) -> void:
	target = n
	_prev_target_pos = target.global_position

func set_inky_partner(n: Node2D) -> void:
	inky_partner = n

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_update_target_velocity()
	var goal = _desired_point()
	var dir = goal - global_position
	if dir.length() > 1.0:
		dir = dir.normalized()
	else:
		dir = Vector2.ZERO
	velocity = dir * speed
	move_and_slide()

func _desired_point() -> Vector2:
	match _chosen:
		"chase":
			return target.global_position
		"ambush":
			return target.global_position + _ahead_vector()
		"inky":
			var pivot = target.global_position + _ahead_vector()
			if inky_partner:
				return pivot + (pivot - inky_partner.global_position)
			else:
				return pivot
		"clyde":
			var d = global_position.distance_to(target.global_position)
			if d >= clyde_radius:
				return target.global_position
			else:
				return _my_scatter
		_:
			return target.global_position

func _ahead_vector() -> Vector2:
	var v = _get_target_velocity()
	if v.length() < 0.001:
		return Vector2.ZERO
	return v.normalized() * ambush_ahead

func _get_target_velocity() -> Vector2:
	if target and "velocity" in target:
		var v = target.velocity
		if typeof(v) == TYPE_VECTOR2:
			return v
	return _target_vel

func _update_target_velocity() -> void:
	if target == null:
		_target_vel = Vector2.ZERO
		return
	var pos = target.global_position
	var inst_vel = pos - _prev_target_pos
	_target_vel = lerp(_target_vel, inst_vel, _vel_smooth)
	_prev_target_pos = pos

func _pick_scatter_corner() -> Vector2:
	if scatter_points.size() >= 4:
		return scatter_points[randi() % scatter_points.size()]
	if target:
		var p = target.global_position
		var dx = 400.0
		var dy = 300.0
		var corners = PackedVector2Array([
			p + Vector2(-dx, -dy), p + Vector2(dx, -dy),
			p + Vector2(-dx,  dy), p + Vector2(dx,  dy)
		])
		return corners[randi() % corners.size()]
	return global_position

func _setup_tint_material() -> void:
	if _sprite == null:
		if sprite_path != NodePath():
			_sprite = get_node_or_null(sprite_path) as Sprite2D
		if _sprite == null:
			for c in get_children():
				if c is Sprite2D:
					_sprite = c
					break
	if _sprite == null:
		return

	if _sprite.material is ShaderMaterial:
		_shader_mat = _sprite.material as ShaderMaterial
	else:
		var sh = Shader.new()
		sh.code = HUE_SHADER_CODE
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = sh
		_sprite.material = _shader_mat

	_shader_mat.set_shader_parameter("strength", clamp(tint_strength, 0.0, 1.0))

func _apply_tint_for_strategy() -> void:
	if _shader_mat == null:
		return
	var col = Color(1, 0, 0)
	match _chosen:
		"chase":
			col = Color("#ff0000")   # Blinky - kırmızı
		"ambush":
			col = Color("#ffb8ff")   # Pinky - pembe
		"inky":
			col = Color("#00ffff")   # Inky  - cyan
		"clyde":
			col = Color("#ffb851")   # Clyde - turuncu
	_shader_mat.set_shader_parameter("target_color", col)
