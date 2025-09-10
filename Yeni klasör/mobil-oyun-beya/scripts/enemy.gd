# Enemy.gd
extends CharacterBody2D

@export var speed: float = 100
@export var target_group: StringName = "player"
@export var target_path: NodePath
@export_enum("random", "chase", "ambush", "inky", "clyde") var strategy: String = "random"

@export var ambush_ahead: float = 160.0
@export var clyde_radius: float = 160.0
@export var scatter_points: PackedVector2Array = []
@export var inky_partner_path: NodePath

@export var world_border_layer: int = 8
@export var stop_radius: float = 20.0

var target: Node2D
var inky_partner: Node2D
var _chosen: String = "chase"

var _prev_target_pos: Vector2 = Vector2.ZERO
var _target_vel: Vector2 = Vector2.ZERO
var _vel_smooth: float = 0.15
var _my_scatter: Vector2 = Vector2.ZERO

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

	# BORDER katmanını mask'e ekle (1-based index)
	var border_bit = 1 << (world_border_layer - 1)
	collision_mask = collision_mask | border_bit

func set_target(n: Node2D) -> void:
	target = n
	_prev_target_pos = target.global_position

func set_inky_partner(n: Node2D) -> void:
	inky_partner = n

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_update_target_velocity()

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	var dir = Vector2.ZERO
	if dist > stop_radius:
		dir = to_target.normalized()

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
