extends Node
class_name GestionnaireHordeFormations

enum Formation { NONE, CONE, WALL }
enum DirectionMode { MOUSE, RANDOM }

@export_node_path("GestionnaireEnnemis") var chemin_ennemis: NodePath
@onready var gm: GestionnaireEnnemis = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis

@export var actif: bool = true
@export var budget_spawn_par_frame: int = 6
@export var rng_seed: int = 1

@export var direction_mode: DirectionMode = DirectionMode.MOUSE
@export var ignorer_interlude: bool = true

@export_group("Déclenchement par vague")
@export var interval_s_par_vague: PackedFloat32Array = PackedFloat32Array([2.0])
@export var chance_par_declenchement_par_vague: PackedFloat32Array = PackedFloat32Array([1.0])

@export_group("Choix formation par vague")
@export var formations_par_vague: Array[PackedInt32Array] = []
@export var poids_formations_par_vague: Array[PackedFloat32Array] = []

@export_group("CONE - défaut")
@export var cone_count_defaut: int = 8
@export var cone_type_idx_defaut: int = 0
@export var cone_rmin_defaut: float = 650.0
@export var cone_rmax_defaut: float = 900.0
@export var cone_angle_deg_defaut: float = 70.0

@export_group("CONE - overrides par vague")
@export var cone_count_par_vague: PackedInt32Array = PackedInt32Array()
@export var cone_type_idx_par_vague: PackedInt32Array = PackedInt32Array()
@export var cone_rmin_par_vague: PackedFloat32Array = PackedFloat32Array()
@export var cone_rmax_par_vague: PackedFloat32Array = PackedFloat32Array()
@export var cone_angle_deg_par_vague: PackedFloat32Array = PackedFloat32Array()

@export_group("WALL - défaut")
@export var wall_count_defaut: int = 12
@export var wall_type_idx_defaut: int = 1
@export var wall_r_defaut: float = 800.0
@export var wall_largeur_defaut: float = 1200.0

@export_group("WALL - overrides par vague")
@export var wall_count_par_vague: PackedInt32Array = PackedInt32Array()
@export var wall_type_idx_par_vague: PackedInt32Array = PackedInt32Array()
@export var wall_r_par_vague: PackedFloat32Array = PackedFloat32Array()
@export var wall_largeur_par_vague: PackedFloat32Array = PackedFloat32Array()

@export var tag_meta: StringName = &"formation"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []
var _formation_id: int = 0

var _cd: float = 0.0

func _ready() -> void:
	rng.seed = rng_seed

func _process(dt: float) -> void:
	if not actif:
		return
	if gm == null or not is_instance_valid(gm) or not is_instance_valid(gm.joueur):
		return

	_consumer_queue()

	if ignorer_interlude and gm.mode_vagues and gm.en_interlude:
		return

	_cd -= dt
	if _cd > 0.0:
		return

	var v: int = _wave_index()
	var interval_s: float = _get_f32(interval_s_par_vague, v, 2.0)
	_cd = max(interval_s, 0.05)

	var chance: float = clamp(_get_f32(chance_par_declenchement_par_vague, v, 1.0), 0.0, 1.0)
	if rng.randf() > chance:
		return

	var f: int = _choisir_formation(v)
	if f == Formation.NONE:
		return
	_declencher_formation(f, v)

func _consumer_queue() -> void:
	if _queue.is_empty():
		return

	var kmax: int = min(budget_spawn_par_frame, _queue.size())
	for _i in range(kmax):
		if gm.ennemis.size() >= gm.max_ennemis:
			_queue.clear()
			return

		var job: Dictionary = _queue.pop_front()

		if not gm.has_method("spawn_force"):
			_queue.clear()
			return

		gm.spawn_force(
			int(job.get("type_idx", 0)),
			job.get("pos", Vector2.ZERO),
			-1,
			job.get("metas", {})
		)

func _wave_index() -> int:
	if gm.mode_vagues and gm.i_vague >= 0:
		return gm.i_vague
	return 0

func _choisir_formation(v: int) -> int:
	if v < formations_par_vague.size() and v < poids_formations_par_vague.size():
		var forms: PackedInt32Array = formations_par_vague[v]
		var w: PackedFloat32Array = poids_formations_par_vague[v]
		if forms.size() > 0 and forms.size() == w.size():
			return _tirage_pondere_int(forms, w)

	if formations_par_vague.size() > 0 and poids_formations_par_vague.size() > 0:
		var last: int = min(formations_par_vague.size(), poids_formations_par_vague.size()) - 1
		if last >= 0:
			var forms2: PackedInt32Array = formations_par_vague[last]
			var w2: PackedFloat32Array = poids_formations_par_vague[last]
			if forms2.size() > 0 and forms2.size() == w2.size():
				return _tirage_pondere_int(forms2, w2)

	return Formation.CONE

func _declencher_formation(f: int, v: int) -> void:
	var dir: Vector2 = _dir_courante()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	match f:
		Formation.CONE:
			var count: int = _get_i32(cone_count_par_vague, v, cone_count_defaut)
			var type_idx: int = _get_i32(cone_type_idx_par_vague, v, cone_type_idx_defaut)
			var rmin: float = _get_f32(cone_rmin_par_vague, v, cone_rmin_defaut)
			var rmax: float = _get_f32(cone_rmax_par_vague, v, cone_rmax_defaut)
			var angle_deg: float = _get_f32(cone_angle_deg_par_vague, v, cone_angle_deg_defaut)
			lancer_cone(count, type_idx, rmin, rmax, angle_deg, dir, tag_meta)

		Formation.WALL:
			var count2: int = _get_i32(wall_count_par_vague, v, wall_count_defaut)
			var type_idx2: int = _get_i32(wall_type_idx_par_vague, v, wall_type_idx_defaut)
			var r: float = _get_f32(wall_r_par_vague, v, wall_r_defaut)
			var largeur: float = _get_f32(wall_largeur_par_vague, v, wall_largeur_defaut)
			lancer_wall(count2, type_idx2, r, largeur, dir, tag_meta)

		_:
			pass

func _dir_courante() -> Vector2:
	match direction_mode:
		DirectionMode.RANDOM:
			var a := rng.randf_range(0.0, TAU)
			return Vector2(cos(a), sin(a))
		_:
			var mouse: Vector2 = get_viewport().get_mouse_position()
			return (mouse - gm.joueur.global_position).normalized()

func lancer_cone(count: int, type_idx: int, rmin: float, rmax: float, angle_deg: float, dir: Vector2, tag: StringName = &"formation") -> void:
	_formation_id += 1
	var fid := _formation_id
	var forward := dir.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT

	for i in range(max(0, count)):
		var pos := _pos_cone(rmin, rmax, angle_deg, forward)
		_queue.append({
			"type_idx": type_idx,
			"pos": pos,
			"metas": {
				"formation_id": fid,
				"spawn_tag": tag,
				"formation_slot": i
			}
		})

func lancer_wall(count: int, type_idx: int, r: float, largeur: float, normal: Vector2, tag: StringName = &"formation") -> void:
	_formation_id += 1
	var fid := _formation_id
	var n := normal.normalized()
	if n == Vector2.ZERO:
		n = Vector2.RIGHT
	var tangent := Vector2(-n.y, n.x)

	for i in range(max(0, count)):
		var t := rng.randf_range(-largeur * 0.5, largeur * 0.5)
		var pos := gm.joueur.global_position + n * r + tangent * t
		_queue.append({
			"type_idx": type_idx,
			"pos": pos,
			"metas": {
				"formation_id": fid,
				"spawn_tag": tag,
				"formation_slot": i
			}
		})

func _pos_cone(rmin: float, rmax: float, angle_deg: float, forward: Vector2) -> Vector2:
	var amax := deg_to_rad(max(0.0, angle_deg) * 0.5)
	var a := rng.randf_range(-amax, amax)
	var rr := rng.randf_range(rmin, rmax)
	var d := forward.rotated(a)
	return gm.joueur.global_position + d * rr

func _tirage_pondere_int(values: PackedInt32Array, weights: PackedFloat32Array) -> int:
	var total := 0.0
	for ww in weights:
		total += max(0.0, ww)
	if total <= 0.0:
		return int(values[0])

	var x := rng.randf() * total
	var s := 0.0
	for i in range(values.size()):
		s += max(0.0, weights[i])
		if x <= s:
			return int(values[i])
	return int(values[0])

func _get_f32(arr: PackedFloat32Array, idx: int, def: float) -> float:
	if idx >= 0 and idx < arr.size():
		return float(arr[idx])
	return def

func _get_i32(arr: PackedInt32Array, idx: int, def: int) -> int:
	if idx >= 0 and idx < arr.size():
		return int(arr[idx])
	return def
