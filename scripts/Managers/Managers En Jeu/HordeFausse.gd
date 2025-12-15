extends Node2D
class_name HordeFausse

@export var joueur_path: NodePath
@export var mm_path: NodePath
@export var texture_ennemi: Texture2D

@export var nombre_instances: int = 600
@export var rayon_min: float = 650.0
@export var rayon_max: float = 1400.0
@export var maj_par_seconde: float = 6.0
@export var verifs_par_tick: int = 80

@export var taille_sprite_px: Vector2 = Vector2(32.0, 32.0)
@export var echelle_min: float = 1.0
@export var echelle_max: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _curseur: int = 0
var _mesh: MultiMesh
var _quad: QuadMesh

@onready var joueur: Node2D = get_node_or_null(joueur_path) as Node2D
@onready var mm: MultiMeshInstance2D = get_node_or_null(mm_path) as MultiMeshInstance2D

func _ready() -> void:
	if mm == null:
		push_error("HordeFausse: mm_path invalide (MultiMeshInstance2D introuvable).")
		return
	if joueur == null:
		push_error("HordeFausse: joueur_path invalide (Node2D introuvable).")
		return

	_rng.randomize()

	if texture_ennemi != null:
		mm.texture = texture_ennemi

	var m: MultiMesh = mm.multimesh
	if m == null:
		m = MultiMesh.new()
		mm.multimesh = m

	var quad: QuadMesh = QuadMesh.new()
	quad.size = taille_sprite_px

	m.mesh = quad
	m.transform_format = MultiMesh.TRANSFORM_2D
	m.use_colors = true
	m.use_custom_data = true
	m.instance_count = int(max(nombre_instances, 1))

	_mesh = m
	_quad = quad

	_remplir()

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0 / float(max(maj_par_seconde, 0.1))
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_tick)

func set_taille_base(px: Vector2) -> void:
	taille_sprite_px = px
	if _quad != null:
		_quad.size = px

func _remplir() -> void:
	if _mesh == null:
		return

	var c: Vector2 = joueur.global_position
	var count: int = _mesh.instance_count

	var smin: float = min(echelle_min, echelle_max)
	var smax: float = max(echelle_min, echelle_max)

	for i: int in range(count):
		var pos: Vector2 = _pos_anneau(c)
		var s: float = _rng.randf_range(smin, smax)
		_mesh.set_instance_transform_2d(i, _transform_instance(pos, s))
		_mesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.65))
		_mesh.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), s, 1.0))

func _tick() -> void:
	if _mesh == null:
		return

	var c: Vector2 = joueur.global_position
	var n: int = _mesh.instance_count
	var kmax: int = int(min(verifs_par_tick, n))

	for _k: int in range(kmax):
		var i: int = _curseur
		_curseur = (i + 1) % n

		var xform: Transform2D = _mesh.get_instance_transform_2d(i)
		var pos_instance: Vector2 = xform.origin
		var d: float = pos_instance.distance_to(c)

		if d < rayon_min or d > rayon_max:
			xform.origin = _pos_anneau(c)
			_mesh.set_instance_transform_2d(i, xform)

func _transform_instance(pos: Vector2, echelle: float) -> Transform2D:
	var xf: Transform2D = Transform2D(0.0, pos)
	if echelle != 1.0:
		xf = xf.scaled(Vector2(echelle, echelle))
	return xf

func _pos_anneau(c: Vector2) -> Vector2:
	var a: float = _rng.randf_range(0.0, TAU)
	var r2: float = _rng.randf_range(rayon_min * rayon_min, rayon_max * rayon_max)
	var r: float = sqrt(r2)
	return c + Vector2(cos(a), sin(a)) * r
