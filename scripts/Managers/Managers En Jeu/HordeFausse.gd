extends Node2D
class_name HordeFausse

@export var joueur_path: NodePath
@export var multimesh_path: NodePath
@export var texture_ennemi: Texture2D

@export var capacite_max: int = 2000
@export var taille_sprite_px: Vector2 = Vector2(32.0, 32.0)
@export var echelle_min: float = 1.0
@export var echelle_max: float = 1.0
@export var alpha_visible: float = 0.65

@export var maj_par_seconde: float = 6.0
@export var verifs_par_tick: int = 80

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mesh: MultiMesh
var _quad: QuadMesh
var _actifs: int = 0
var _curseur: int = 0

var _anneau_min: float = 650.0
var _anneau_max: float = 1400.0

@onready var joueur: Node2D = get_node_or_null(joueur_path) as Node2D
@onready var mm: MultiMeshInstance2D = get_node_or_null(multimesh_path) as MultiMeshInstance2D

func _ready() -> void:
	if mm == null:
		push_error("HordeFausse: multimesh_path invalide.")
		return
	if joueur == null:
		push_error("HordeFausse: joueur_path invalide.")
		return

	_rng.randomize()

	if texture_ennemi != null:
		mm.texture = texture_ennemi

	_quad = QuadMesh.new()
	_quad.size = taille_sprite_px

	_mesh = MultiMesh.new()
	_mesh.mesh = _quad
	_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_mesh.use_colors = true
	_mesh.use_custom_data = false
	_mesh.instance_count = int(max(capacite_max, 1))

	mm.multimesh = _mesh

	_initialiser_instances()
	set_nombre_actif(0)

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0 / float(max(maj_par_seconde, 0.1))
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_tick)

func configurer_anneau(rayon_min: float, rayon_max: float) -> void:
	var rmin: float = min(rayon_min, rayon_max)
	var rmax: float = max(rayon_min, rayon_max)
	_anneau_min = max(0.0, rmin)
	_anneau_max = max(_anneau_min + 1.0, rmax)

	if _mesh == null or joueur == null:
		return

	var c: Vector2 = joueur.global_position
	for i: int in range(_actifs):
		var xf: Transform2D = _mesh.get_instance_transform_2d(i)
		xf.origin = _pos_anneau(c)
		_mesh.set_instance_transform_2d(i, xf)

func set_nombre_actif(n: int) -> void:
	if _mesh == null or joueur == null:
		return

	var count: int = _mesh.instance_count
	var new_n: int = clamp(n, 0, count)
	if new_n == _actifs:
		return

	var c: Vector2 = joueur.global_position

	if new_n > _actifs:
		for i: int in range(_actifs, new_n):
			var xf: Transform2D = _mesh.get_instance_transform_2d(i)
			xf.origin = _pos_anneau(c)
			_mesh.set_instance_transform_2d(i, xf)

			var col: Color = _mesh.get_instance_color(i)
			col.a = alpha_visible
			_mesh.set_instance_color(i, col)
	else:
		for i: int in range(new_n, _actifs):
			var col: Color = _mesh.get_instance_color(i)
			col.a = 0.0
			_mesh.set_instance_color(i, col)

	_actifs = new_n
	_curseur = 0 if _actifs <= 0 else (_curseur % _actifs)

func _initialiser_instances() -> void:
	if _mesh == null or joueur == null:
		return

	var c: Vector2 = joueur.global_position
	var count: int = _mesh.instance_count

	var smin: float = min(echelle_min, echelle_max)
	var smax: float = max(echelle_min, echelle_max)

	for i: int in range(count):
		var pos: Vector2 = _pos_anneau(c)
		var s: float = _rng.randf_range(smin, smax)

		var xf: Transform2D = Transform2D(0.0, pos)
		xf.x *= s
		xf.y *= s

		_mesh.set_instance_transform_2d(i, xf)
		_mesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))

func _tick() -> void:
	if _mesh == null or joueur == null or _actifs <= 0:
		return

	var c: Vector2 = joueur.global_position
	var n: int = _actifs
	var kmax: int = int(min(verifs_par_tick, n))

	for _k: int in range(kmax):
		var i: int = _curseur
		_curseur = (i + 1) % n

		var xf: Transform2D = _mesh.get_instance_transform_2d(i)
		var d: float = xf.origin.distance_to(c)

		if d < _anneau_min or d > _anneau_max:
			xf.origin = _pos_anneau(c)
			_mesh.set_instance_transform_2d(i, xf)

func _pos_anneau(c: Vector2) -> Vector2:
	var a: float = _rng.randf_range(0.0, TAU)
	var r2: float = _rng.randf_range(_anneau_min * _anneau_min, _anneau_max * _anneau_max)
	var r: float = sqrt(r2)
	return c + Vector2(cos(a), sin(a)) * r
