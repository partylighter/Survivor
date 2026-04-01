class_name GestionnaireZones
extends Node

# ---------------------------------------------------------------------------
# Signaux
# ---------------------------------------------------------------------------

## Émis quand le joueur franchit la frontière entre deux zones.
signal zone_changee(ancienne: ZoneDefinition, nouvelle: ZoneDefinition)
## Émis au moment où le boss de la zone est instancié.
signal boss_spawne(boss: Node2D)
## Émis quand le boss meurt et que la progression est débloquée.
signal boss_mort
## Émis quand l'état de blocage horizontal du joueur change.
signal avance_bloquee_changee(bloquee: bool)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Liste de toutes les zones, dans n'importe quel ordre —
## triées automatiquement par x_debut_px dans _ready().
@export var zones: Array[ZoneDefinition] = []

## Référence au gestionnaire d'ennemis pour le spawn du boss.
@export var gestionnaire_ennemis: GestionnaireEnnemis = null

# ---------------------------------------------------------------------------
# État interne
# ---------------------------------------------------------------------------

## Zone dans laquelle se trouve actuellement le joueur.
var zone_active:    ZoneDefinition = null
## Vrai si le joueur ne peut pas avancer (boss vivant).
var avance_bloquee: bool           = false

var _joueur:          Node2D     = null
var _boss_actuel:     Node2D     = null
var _zone_idx_active: int        = -1
## zone_idx (int) → true une fois le boss de cette zone tué.
var _boss_tues:       Dictionary = {}

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Tri décroissant — les zones vont de droite (X élevé) vers gauche (X faible).
	zones.sort_custom(func(a: ZoneDefinition, b: ZoneDefinition) -> bool:
		return a.x_debut_px > b.x_debut_px)
	_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D

# ---------------------------------------------------------------------------
# Boucle
# ---------------------------------------------------------------------------

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D
		return
	_verifier_zone(_joueur.global_position.x)

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

## Retourne la ZoneDefinition correspondant à la position X (zones droite→gauche).
func zone_en(x: float) -> ZoneDefinition:
	for z: ZoneDefinition in zones:
		if x <= z.x_debut_px and x > z.x_fin_px:
			return z
	return zones.back() if not zones.is_empty() else null

## Retourne l'index dans le tableau zones, ou -1 si vide (zones droite→gauche).
func index_zone_en(x: float) -> int:
	for i: int in range(zones.size()):
		if x <= zones[i].x_debut_px and x > zones[i].x_fin_px:
			return i
	if zones.is_empty():
		return -1
	# À droite de toutes les zones → zone 0 ; à gauche → dernière zone.
	if x > zones[0].x_debut_px:
		return 0
	return zones.size() - 1

# ---------------------------------------------------------------------------
# Suivi de zone
# ---------------------------------------------------------------------------

func _verifier_zone(x: float) -> void:
	var idx: int = index_zone_en(x)
	if idx == _zone_idx_active:
		return

	var ancienne: ZoneDefinition = zone_active
	_zone_idx_active = idx
	zone_active      = zones[idx] if idx >= 0 else null
	emit_signal("zone_changee", ancienne, zone_active)

	if zone_active != null and zone_active.est_zone_boss:
		_gerer_entree_boss(idx)

# ---------------------------------------------------------------------------
# Logique boss
# ---------------------------------------------------------------------------

func _gerer_entree_boss(zone_idx: int) -> void:
	# Boss déjà tué lors d'une run précédente dans cette zone → pas de blocage.
	if _boss_tues.get(zone_idx, false):
		return

	# Le joueur est revenu en arrière alors que le boss est encore vivant →
	# réappliquer le blocage sans respawner.
	if is_instance_valid(_boss_actuel):
		_set_avance_bloquee(true)
		return

	if gestionnaire_ennemis == null or not is_instance_valid(gestionnaire_ennemis):
		push_warning("GestionnaireZones: gestionnaire_ennemis non assigné, impossible de spawner le boss.")
		return
	if zone_active.scene_boss == null:
		push_warning("GestionnaireZones: zone boss '%s' sans scene_boss." % zone_active.nom)
		return

	var pos: Vector2 = Vector2(
		zone_active.x_debut_px + (zone_active.x_fin_px - zone_active.x_debut_px) * 0.5,
		_joueur.global_position.y if is_instance_valid(_joueur) else 0.0
	)

	_boss_actuel = gestionnaire_ennemis.spawn_scene_directe(zone_active.scene_boss, pos)
	if _boss_actuel == null:
		push_warning("GestionnaireZones: spawn_scene_directe a retourné null pour le boss.")
		return

	if _boss_actuel.has_signal("mort"):
		_boss_actuel.connect("mort", _sur_mort_boss.bind(zone_idx), CONNECT_ONE_SHOT)

	_set_avance_bloquee(true)
	emit_signal("boss_spawne", _boss_actuel)

func _sur_mort_boss(zone_idx: int) -> void:
	_boss_tues[zone_idx] = true
	_boss_actuel         = null
	_set_avance_bloquee(false)
	emit_signal("boss_mort")

# ---------------------------------------------------------------------------
# Blocage du joueur
# ---------------------------------------------------------------------------

func _set_avance_bloquee(v: bool) -> void:
	if avance_bloquee == v:
		return
	avance_bloquee = v

	# Jeu droite→gauche : le boss bloque la progression vers la gauche.
	if is_instance_valid(_joueur) and _joueur.has_method("set_limite_gauche"):
		var limite: float = -INF
		if v and zone_active != null:
			limite = zone_active.x_fin_px
		_joueur.call("set_limite_gauche", limite)

	emit_signal("avance_bloquee_changee", v)
