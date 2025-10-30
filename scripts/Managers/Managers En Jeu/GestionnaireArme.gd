extends Node2D
class_name GestionnaireArme

@export_node_path("Node2D") var chemin_socket_principale: NodePath
@export_node_path("Node2D") var chemin_socket_secondaire: NodePath
@export_node_path("ZoneRamassage") var chemin_zone: NodePath
var zone: ZoneRamassage

# Portée des bras (distance radiale mini / maxi)
@export_range(0.0, 1000.0, 0.1) var distance_min: float = 300.0
@export_range(0.0, 1000.0, 0.1) var distance_max: float = 500.0

# Lissage du bras principal (0.0 lent, 1.0 réactif)
@export_range(0.0, 1.0, 0.01) var vitesse_lissage: float = 0.05

# Réactivité bras secondaire (0.2 lent/stable, 1.0 nerveux)
@export_range(0.01, 1.0, 0.01) var reactivite_main_secondaire: float = 1.0

# Limite de vitesse angulaire de la main secondaire (radians/frame)
@export_range(0.0, 3.14159, 0.01) var vitesse_offset_max: float = 0.25

# Zones de distance pour fusion visuelle des deux mains
# dist <= rayon_proche  -> mains opposées
# dist >= rayon_loin    -> mains sur le même côté (fusion visuelle)
@export_range(0.0, 2000.0, 0.1) var rayon_proche: float = 800.0
@export_range(0.0, 2000.0, 0.1) var rayon_loin: float = 1500.0

# Avance max quand la main secondaire dépasse la principale (radians)
# Exemple: PI * 0.5 = 90°
@export_range(0.0, 3.14159, 0.01) var avance_max: float = PI * 3.14

# Séparation visuelle des deux mains quand elles sont du même côté
@export_range(0.0, 64.0, 0.1) var ecart_lateral: float = 6.0

# Portée relative (1.0 = bras tendu au max, <1.0 = bras plus rentré)
@export_range(0.1, 1.0, 0.01) var portee_main_principale: float = 1.0
@export_range(0.1, 1.0, 0.01) var portee_main_secondaire: float = 0.7

@export var auto_flip_visuel: bool = true

var arme_principale: ArmeBase = null
var arme_secondaire: ArmeBase = null

var _socket_principale: Node2D
var _socket_secondaire: Node2D
var _joueur: Player

# distances lissées
var _dist_principale: float
var _dist_secondaire: float

# angles affichés
var _angle_main_affiche: float
var _angle_secondaire_affiche: float

# facteur fusion visuelle (0.0 = opposées, 1.0 = même côté)
var _fusion_t: float = 0.0

# décalage angulaire actuel de la main secondaire par rapport à la principale
# proche    -> ~PI (180° derrière)
# milieu    -> ~0  (mêmes direction)
# très loin -> ~-avance_max (elle passe devant)
var _offset_secondaire_affiche: float = PI
const LOOT_SCENE: PackedScene = preload("res://scenes/Armes/Armes de contact/loot_arme.tscn")


func _ready() -> void:
	_socket_principale = get_node(chemin_socket_principale) as Node2D
	_socket_secondaire = get_node(chemin_socket_secondaire) as Node2D
	zone = get_node(chemin_zone) as ZoneRamassage
	_joueur = get_parent() as Player

	_dist_principale = distance_max
	_dist_secondaire = distance_max

	_angle_main_affiche = 0.0
	_angle_secondaire_affiche = 0.0

	_fusion_t = 0.0
	_offset_secondaire_affiche = PI


func _process(_dt: float) -> void:
	_handle_inputs()
	_mettre_a_jour_sockets()
	_gestion_attaques()


func _mettre_a_jour_sockets() -> void:
	var cible: Vector2 = get_global_mouse_position()
	var diff: Vector2 = cible - global_position
	var dist: float = diff.length()
	if dist < 0.001:
		return

	# angle cible du bras principal = direction souris
	var angle_main_cible: float = diff.angle()

	# 1. calcul du facteur de fusion visuelle (sert juste à l'écart latéral)
	#    0 = bras opposés, 1 = bras même côté
	var fusion_cible: float = _calculer_fusion_depuis_distance(dist)
	_fusion_t = lerp(_fusion_t, fusion_cible, vitesse_lissage)

	# 2. offset angulaire cible pour le bras secondaire
	#    mapping continu unique sur toute la plage de distance
	#    dist = rayon_proche      -> PI        (opposé)
	#    dist = distance_max      -> -avance_max (dépasse)
	#    la distance où offset == 0 (les mains se touchent) tombe naturellement entre les deux
	var offset_target_raw: float = _calculer_offset_continu(dist)

	# 3. limite de vitesse angulaire de la main secondaire
	var delta_off: float = wrapf(
		offset_target_raw - _offset_secondaire_affiche,
		-PI,
		PI
	)

	if delta_off > vitesse_offset_max:
		delta_off = vitesse_offset_max
	elif delta_off < -vitesse_offset_max:
		delta_off = -vitesse_offset_max

	var offset_limite: float = _offset_secondaire_affiche + delta_off

	# 4. lissage final de l'offset secondaire (réactivité propre au bras secondaire)
	_offset_secondaire_affiche = lerp(
		_offset_secondaire_affiche,
		offset_limite,
		vitesse_lissage * reactivite_main_secondaire
	)

	# 5. lissage de l'angle du bras principal
	_angle_main_affiche = lerp_angle(
		_angle_main_affiche,
		angle_main_cible,
		vitesse_lissage
	)

	# 6. angle final du bras secondaire
	_angle_secondaire_affiche = wrapf(
		_angle_main_affiche + _offset_secondaire_affiche,
		-PI,
		PI
	)

	# 7. portée radiale des deux bras
	var distance_cible: float = clamp(dist, distance_min, distance_max)

	var cible_dist_main: float = distance_cible * portee_main_principale
	var cible_dist_secondaire: float = distance_cible * portee_main_secondaire

	_dist_principale = lerp(
		_dist_principale,
		cible_dist_main,
		vitesse_lissage
	)

	_dist_secondaire = lerp(
		_dist_secondaire,
		cible_dist_secondaire,
		vitesse_lissage * reactivite_main_secondaire
	)

	# 8. vecteurs de direction pour placer les sockets
	var dir_main: Vector2 = Vector2(cos(_angle_main_affiche), sin(_angle_main_affiche))
	var dir_secondaire: Vector2 = Vector2(cos(_angle_secondaire_affiche), sin(_angle_secondaire_affiche))

	# perpendiculaire basée sur le bras principal (juste pour l'écart visuel)
	var dir_perp: Vector2 = Vector2(-dir_main.y, dir_main.x)

	# écart visuel seulement quand les bras sont sur le même côté
	var offset_vec: Vector2 = dir_perp * ecart_lateral * _fusion_t

	# positions finales
	_socket_principale.position  = dir_main       * _dist_principale  + offset_vec
	_socket_secondaire.position = dir_secondaire * _dist_secondaire - offset_vec

	# rotations finales
	_socket_principale.rotation = _angle_main_affiche
	_socket_secondaire.rotation = _angle_secondaire_affiche

	if arme_principale:
		arme_principale.rotation = _angle_main_affiche
	if arme_secondaire:
		arme_secondaire.rotation = _angle_secondaire_affiche
	if auto_flip_visuel:
		_appliquer_flip_visuel(_socket_principale, _angle_main_affiche)
		_appliquer_flip_visuel(_socket_secondaire, _angle_secondaire_affiche)


func _essayer_ramasser() -> void:
	if not is_instance_valid(zone):
		print("ramasser: pas de zone"); return
	var ref_pos: Vector2 = ( _joueur.global_position if is_instance_valid(_joueur) else global_position )
	var loot: LootArme = zone.get_loot_le_plus_proche(ref_pos)
	if loot == null:
		print("ramasser: rien"); return
	var ps: PackedScene = loot.arme_scene
	if ps == null:
		print("ramasser: arme_scene manquante"); return
	var n := ps.instantiate()
	if n is ArmeBase:
		var arme := n as ArmeBase
		arme.scene_source = ps
		if arme_principale == null:
			equiper_arme_principale(arme); print("ramasser: principale")
		elif arme_secondaire == null:
			equiper_arme_secondaire(arme); print("ramasser: secondaire")
		else:
			print("ramasser: mains pleines"); arme.queue_free(); return
		loot.queue_free(); print("ramasser: ok")
	else:
		print("ramasser: type invalide"); n.queue_free()

func _appliquer_flip_visuel(n: Node2D, angle: float) -> void:
	var a := wrapf(angle, -PI, PI)
	var doit_flip := (a > PI * 0.5) or (a < -PI * 0.5)  # à l'envers ?
	var s := n.scale
	s.y = -1.0 if doit_flip else 1.0
	n.scale = s

func _calculer_fusion_depuis_distance(dist: float) -> float:
	# but:
	# - sert juste à visuel/ecart_lateral
	# - 0 près du joueur = mains opposées
	# - 1 loin = mains du même côté
	var r1: float = rayon_proche
	var r2: float = max(rayon_loin, r1 + 0.001)

	if dist <= r1:
		return 0.0
	if dist >= r2:
		return 1.0

	var ratio: float = (dist - r1) / (r2 - r1)
	return clamp(ratio, 0.0, 1.0)


func _calculer_offset_continu(dist: float) -> float:
	# mapping continu de l'offset angulaire sur toute la plage
	# offset(dist) = PI  ->  bras secondaire derrière
	# offset(dist) -> 0  ->  bras secondaire rejoint la principale
	# offset(dist) -> -avance_max -> bras secondaire passe devant
	#
	# on interpole linéairement entre rayon_proche et distance_max.
	# pas de rupture de pente à "point de contact". même ressenti partout.

	var r_start: float = rayon_proche
	var r_end: float = max(max(distance_max, rayon_loin), r_start + 0.001)

	# t_global = 0 à r_start, 1 à r_end
	var t_global: float = (dist - r_start) / (r_end - r_start)
	t_global = clamp(t_global, 0.0, 1.0)

	# interpolate PI -> -avance_max
	return lerp(PI, -avance_max, t_global)


func _gestion_attaques() -> void:
	if Input.is_action_just_pressed("attaque_main_droite"):
		if arme_principale and arme_principale.peut_attaquer():
			arme_principale.attaquer()
		print("attaque arme principale")

	if Input.is_action_just_pressed("attaque_main_gauche"):
		if arme_secondaire and arme_secondaire.peut_attaquer():
			arme_secondaire.attaquer()
		print("attaque arme secondaire")

func equiper_arme_principale(a: ArmeBase) -> void:
	if a == null:
		return
	arme_principale = a
	a.equipe_par(_joueur)
	_socket_principale.add_child(a)
	a.position = Vector2.ZERO
	a.rotation = _socket_principale.rotation
	_angle_main_affiche = _socket_principale.rotation


func equiper_arme_secondaire(a: ArmeBase) -> void:
	if a == null:
		return
	arme_secondaire = a
	a.equipe_par(_joueur)
	_socket_secondaire.add_child(a)
	a.position = Vector2.ZERO
	a.rotation = _socket_secondaire.rotation
	_angle_secondaire_affiche = _socket_secondaire.rotation
	_offset_secondaire_affiche = PI

func _lacher(main_droite: bool) -> void:
	_liberer(main_droite, 110.0, (8.0 if main_droite else -8.0))

func _jeter(main_droite: bool) -> void:
	_liberer(main_droite, 700.0, (20.0 if main_droite else -20.0))

func _drop(a: ArmeBase, s: Node2D, force: float, ang_vel: float) -> void:
	if a.scene_source == null:
		print("drop: scene_source manquante"); return
	var loot := _spawn_loot(s, a.scene_source, force, ang_vel)
	if loot == null: return
	if a == arme_principale: arme_principale = null 
	else: arme_secondaire = null
	a.queue_free()
	print("drop ok:", loot.name)

func _handle_inputs() -> void:
	if Input.is_action_just_pressed("ramasser"):
		_essayer_ramasser()
	elif Input.is_action_just_pressed("lacher_main_droite"):
		_lacher(true)
	elif Input.is_action_just_pressed("lacher_main_gauche"):
		_lacher(false)
	elif Input.is_action_just_pressed("jeter_main_droite"):
		_jeter(true)
	elif Input.is_action_just_pressed("jeter_main_gauche"):
		_jeter(false)

func _liberer(main_droite: bool, force: float, ang_vel: float) -> void:
	var a: ArmeBase = (arme_principale if main_droite else arme_secondaire)
	var s: Node2D = (_socket_principale if main_droite else _socket_secondaire)
	if a == null or s == null:
		print("liberer: rien en main"); return
	_drop(a, s, force, ang_vel)

func _spawn_loot(s: Node2D, scene_src: PackedScene, force: float, ang_vel: float) -> LootArme:
	if scene_src == null:
		print("spawn_loot: scene_src null"); return null
	var loot := LOOT_SCENE.instantiate() as LootArme
	loot.arme_scene = scene_src

	var dir := (get_global_mouse_position() - s.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(s.global_rotation)
	var jitter := dir.orthogonal() * randf_range(-25.0, 25.0)

	loot.global_position = s.global_position
	loot.linear_velocity = dir * force + jitter
	loot.angular_velocity = ang_vel

	loot.z = 0.8
	loot.vz = (100.0 if force <= 150.0 else 280.0)

	get_tree().current_scene.add_child(loot)
	return loot
