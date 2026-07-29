extends Control
class_name ZoneMoulage

@onready var conteneur_lignes: Control = $Lignes
@onready var modele_ligne: ColorRect = $Lignes/ModeleLigne
@onready var conteneur_points: Control = $Points
@onready var modele_point: ColorRect = $Points/ModelePoint

var gestionnaire: GestionnaireMoulage
var controles_lignes: Array[ColorRect] = []
var controles_points: Array[ColorRect] = []

func _ready() -> void:
	resized.connect(rafraichir)

func definir_gestionnaire(nouveau_gestionnaire: GestionnaireMoulage) -> void:
	gestionnaire = nouveau_gestionnaire
	rafraichir()

func rafraichir() -> void:
	if not is_node_ready():
		return
	if gestionnaire == null or gestionnaire.points.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		_masquer_controles()
		return
	if gestionnaire.index_point_actuel < 0 or gestionnaire.index_point_actuel >= gestionnaire.points.size():
		_masquer_controles()
		return
	var positions: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in gestionnaire.points:
		positions.append(point * size)
	var dernier_point_affiche: int = mini(gestionnaire.index_point_actuel + 5, positions.size() - 1)
	var zone_visible := Rect2(Vector2.ZERO, size)
	var nombre_points_affiches: int = dernier_point_affiche - gestionnaire.index_point_actuel + 1
	_assurer_nombre_points(nombre_points_affiches)
	_assurer_nombre_lignes(maxi(nombre_points_affiches - 1, 0))
	var dimension: float = minf(size.x, size.y)
	var rayon: float = gestionnaire.rayon_point_actuel * dimension
	var taille_point: float = maxf(rayon * 2.0 + 18.0, 30.0)
	for index_affiche: int in nombre_points_affiches:
		var index_point: int = gestionnaire.index_point_actuel + index_affiche
		var controle_point: ColorRect = controles_points[index_affiche]
		var centre_point: Vector2 = positions[index_point]
		controle_point.visible = zone_visible.has_point(centre_point)
		if not controle_point.visible:
			continue
		controle_point.position = centre_point - Vector2.ONE * taille_point * 0.5
		controle_point.size = Vector2.ONE * taille_point
		var materiau: ShaderMaterial = controle_point.material as ShaderMaterial
		var actif: bool = index_affiche == 0
		var attenuation: float = 1.0 if actif else maxf(0.28, 0.72 - 0.09 * float(index_affiche))
		materiau.set_shader_parameter("couleur_point", Color(0.88, 0.88, 0.9, 1.0) if actif else Color(0.34, 0.34, 0.37, attenuation))
		materiau.set_shader_parameter("couleur_contour", Color(1.0, 1.0, 1.0, 1.0 if actif else attenuation))
		materiau.set_shader_parameter("point_actif", 1.0 if actif else 0.0)
		materiau.set_shader_parameter("progression", clampf(gestionnaire.temps_sur_point / maxf(gestionnaire.duree_point_actuelle, 0.001), 0.0, 1.0) if actif else 0.0)
		materiau.set_shader_parameter("avertissement", 1.0 if actif and gestionnaire.secousse_est_imminente() else 0.0)
		materiau.set_shader_parameter("secousse", 1.0 if actif and gestionnaire.temps_secousse_restant > 0.0 else 0.0)
	for index_ligne: int in range(nombre_points_affiches - 1):
		var controle_ligne: ColorRect = controles_lignes[index_ligne]
		var point_depart: Vector2 = positions[gestionnaire.index_point_actuel + index_ligne]
		var point_arrivee: Vector2 = positions[gestionnaire.index_point_actuel + index_ligne + 1]
		var direction: Vector2 = point_arrivee - point_depart
		controle_ligne.visible = zone_visible.has_point(point_depart) and zone_visible.has_point(point_arrivee) and absf(direction.x) <= size.x * 0.5
		if not controle_ligne.visible:
			continue
		controle_ligne.position = point_depart
		controle_ligne.size = Vector2(direction.length(), 3.0)
		controle_ligne.rotation = direction.angle()

func _assurer_nombre_points(nombre: int) -> void:
	while controles_points.size() < nombre:
		var controle: ColorRect = modele_point.duplicate() as ColorRect
		controle.name = "Point%d" % (controles_points.size() + 1)
		controle.material = modele_point.material.duplicate()
		controle.visible = true
		conteneur_points.add_child(controle)
		controles_points.append(controle)
	for index: int in controles_points.size():
		controles_points[index].visible = index < nombre

func _assurer_nombre_lignes(nombre: int) -> void:
	while controles_lignes.size() < nombre:
		var controle: ColorRect = modele_ligne.duplicate() as ColorRect
		controle.name = "Ligne%d" % (controles_lignes.size() + 1)
		controle.visible = true
		conteneur_lignes.add_child(controle)
		controles_lignes.append(controle)
	for index: int in controles_lignes.size():
		controles_lignes[index].visible = index < nombre

func _masquer_controles() -> void:
	for controle: ColorRect in controles_points:
		controle.visible = false
	for controle: ColorRect in controles_lignes:
		controle.visible = false
