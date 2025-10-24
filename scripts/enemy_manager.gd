extends Node2D
class_name EnemyManager

@export var count: int = 20000
@export var speed: float = 90.0
@export_range(0.0, 1.0, 0.01) var accel: float = 0.2
@export var update_budget: int = 4000

@export var render_radius: float = 1200.0
@export var sim_radius: float = 1400.0
@export var enemy_radius: float = 8.0

@export var anim_fps: float = 8.0
@export var atlas_cols: int = 8
@export var atlas_rows: int = 8
@export var hit_flash_time: float = 0.08

@export_node_path("Node2D") var player_path: NodePath

@export var real_nodes_enabled: bool = true
@export var max_real_nodes: int = 150
@export var real_nodes_radius: float = 350.0
@export var enemy_scene: PackedScene

@onready var mmi: MultiMeshInstance2D = $MMI
@onready var player: Node2D = get_node_or_null(player_path)
@export var atlas: Texture2D
var mm: MultiMesh

var pos: PackedVector2Array
var vel: PackedVector2Array
var hp: PackedInt32Array
var hit_timer: PackedFloat32Array
var frame_idx: PackedInt32Array

var _idx: int = 0
var _r2_render: float
var _r2_sim: float

const CELL := 64
var buckets: Dictionary = {}
var _real_map: Dictionary = {}

func _ready() -> void:
	_r2_render = render_radius * render_radius
	_r2_sim = sim_radius * sim_radius

	pos = PackedVector2Array(); pos.resize(count)
	vel = PackedVector2Array(); vel.resize(count)
	hp = PackedInt32Array(); hp.resize(count)
	hit_timer = PackedFloat32Array(); hit_timer.resize(count)
	frame_idx = PackedInt32Array(); frame_idx.resize(count)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(count):
		pos[i] = Vector2(rng.randf_range(-3000.0, 3000.0), rng.randf_range(-3000.0, 3000.0))
		vel[i] = Vector2.ZERO
		hp[i] = 1
		hit_timer[i] = 0.0
		frame_idx[i] = 0
	mmi.texture = atlas
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.instance_count = count
	mmi.multimesh = mm
	mmi.texture = atlas                  # ← d’abord la texture
	# mmi.material doit être un ShaderMaterial canvas_item qui lit TEXTURE
	mmi.multimesh = mm                   # ← ensuite le multimesh
	var mat: ShaderMaterial = mmi.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("grid", Vector2i(atlas_cols, atlas_rows))

func _process(dt: float) -> void:
	if player == null:
		return
	_update_subset(dt)
	_rebuild_buckets()
	var visible_ids: PackedInt32Array = _render_compact()
	if real_nodes_enabled and enemy_scene:
		_sync_real_nodes(visible_ids)

func _update_subset(dt: float) -> void:
	var p: Vector2 = player.global_position
	var n: int = min(update_budget, count)
	for _k: int in range(n):
		var i: int = _idx
		if hp[i] > 0:
			var d: Vector2 = p - pos[i]
			var d2: float = d.length_squared()
			if d2 <= _r2_sim:
				var L: float = sqrt(d2)
				var dir: Vector2 = d / (L if L > 1e-4 else 1.0)
				vel[i] = vel[i].lerp(dir * speed, 1.0 - pow(1.0 - accel, 60.0 * dt))
				pos[i] += vel[i] * dt
				var nframes: int = max(1, atlas_cols * atlas_rows)
				var f: float = float(frame_idx[i]) + anim_fps * dt
				f = fmod(f, float(nframes))
				frame_idx[i] = int(f)
			if hit_timer[i] > 0.0:
				hit_timer[i] = max(0.0, hit_timer[i] - dt)
		_idx = (_idx + 1) % count

func _render_compact() -> PackedInt32Array:
	var p: Vector2 = player.global_position
	var vis: int = 0
	var keep: PackedInt32Array = PackedInt32Array()
	keep.resize(min(count, 4096))

	for i: int in range(count):
		if hp[i] <= 0: continue
		if (pos[i] - p).length_squared() > _r2_render: continue
		mm.set_instance_transform_2d(vis, Transform2D(0.0, pos[i]))
		var nframes: int = max(1, atlas_cols * atlas_rows)
		var frame_norm: float = float(frame_idx[i]) / float(nframes - 1)
		var flash: float = 1.0 if hit_timer[i] > 0.0 else 0.0
		mm.set_instance_custom_data(vis, Color(frame_norm, flash, 0.0, 0.0))
		if vis >= keep.size(): keep.resize(vis + 64)
		keep[vis] = i
		vis += 1

	mmi.multimesh.visible_instance_count = vis
	keep.resize(vis)
	return keep

func damage_circle(center: Vector2, radius: float, dmg: int) -> int:
	var hits: int = 0
	var c: Vector2i = _cell(center)
	var r: int = int(ceil(radius / CELL))
	for ox: int in range(-r, r + 1):
		for oy: int in range(-r, r + 1):
			var ids: Array = buckets.get(_key(c + Vector2i(ox, oy)), [])
			for i in ids:
				var idx: int = int(i)
				if hp[idx] <= 0: continue
				var rr: float = radius + enemy_radius
				if center.distance_squared_to(pos[idx]) <= rr * rr:
					hp[idx] = max(0, hp[idx] - dmg)
					hit_timer[idx] = hit_flash_time
					hits += 1
	return hits

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func _key(c: Vector2i) -> int:
	return (c.x << 16) ^ (c.y & 0xFFFF)

func _rebuild_buckets() -> void:
	buckets.clear()
	for i: int in range(count):
		if hp[i] <= 0: continue
		var k: int = _key(_cell(pos[i]))
		if not buckets.has(k): buckets[k] = []
		(buckets[k] as Array).append(i)

func _sync_real_nodes(visible_ids: PackedInt32Array) -> void:
	var p: Vector2 = player.global_position
	var want: Array = []
	var want_count: int = 0
	var r2: float = real_nodes_radius * real_nodes_radius

	for id: int in visible_ids:
		if (pos[id] - p).length_squared() <= r2:
			want.append(id)
			want_count += 1
			if want_count >= max_real_nodes: break

	for id_var in _real_map.keys():
		var id_rm: int = int(id_var)
		if want.find(id_rm) == -1 or hp[id_rm] <= 0:
			(_real_map[id_rm] as Node2D).queue_free()
			_real_map.erase(id_rm)

	for id in want:
		var eid: int = int(id)
		var node: Node2D = _real_map.get(eid, null)
		if node == null:
			node = enemy_scene.instantiate() as Node2D
			add_child(node)
			_real_map[eid] = node
		node.global_position = pos[eid]
