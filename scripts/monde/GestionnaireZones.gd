class_name GestionnaireZones
extends Node2D

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

@export_group("Debug Draw")
@export var debug_draw: bool = false:
	set(v):
		debug_draw = v
		queue_redraw()
		set_process(debug_draw)
@export var debug_draw_y_min: float = -1200.0
@export var debug_draw_y_max: float = 1200.0
@export var debug_draw_couleur_zone: Color = Color(0.2, 0.7, 1.0, 0.10)
@export var debug_draw_couleur_zone_active: Color = Color(1.0, 0.75, 0.2, 0.18)
@export var debug_draw_couleur_bordure: Color = Color(1, 1, 1, 0.55)
@export var debug_draw_couleur_boss: Color = Color(1.0, 0.2, 0.2, 0.14)

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
	# Tri défensif — l'ordre dans l'inspecteur ne compte pas.
	zones.sort_custom(func(a: ZoneDefinition, b: ZoneDefinition) -> bool:
		return a.x_debut_px < b.x_debut_px)
	_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D
	set_process(debug_draw)
	queue_redraw()

# ---------------------------------------------------------------------------
# Boucle
# ---------------------------------------------------------------------------

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D
		queue_redraw()
		return
	_verifier_zone(_joueur.global_position.x)
	if debug_draw:
		queue_redraw()

func _process(_dt: float) -> void:
	if debug_draw:
		queue_redraw()

func _draw() -> void:
	if not debug_draw or zones.is_empty():
		return

	var y_min: float = minf(debug_draw_y_min, debug_draw_y_max)
	var y_max: float = maxf(debug_draw_y_min, debug_draw_y_max)
	var hauteur: float = y_max - y_min
	if hauteur <= 0.0:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size

	for i: int in range(zones.size()):
		var z: ZoneDefinition = zones[i]
		if z == null:
			continue

		var x_min: float = minf(z.x_debut_px, z.x_fin_px)
		var x_max: float = maxf(z.x_debut_px, z.x_fin_px)
		var rect := Rect2(Vector2(x_min, y_min), Vector2(x_max - x_min, hauteur))

		var couleur_fond: Color = debug_draw_couleur_zone_active if i == _zone_idx_active else debug_draw_couleur_zone
		if z.est_zone_boss:
			couleur_fond = debug_draw_couleur_boss if i != _zone_idx_active else debug_draw_couleur_zone_active

		draw_rect(rect, couleur_fond, true)
		draw_rect(rect, debug_draw_couleur_bordure, false, 3.0)
		draw_line(Vector2(x_min, y_min), Vector2(x_min, y_max), debug_draw_couleur_bordure, 2.0)
		draw_line(Vector2(x_max, y_min), Vector2(x_max, y_max), debug_draw_couleur_bordure, 2.0)

		if font != null:
			var nom_zone: String = String(z.nom)
			if nom_zone.is_empty():
				nom_zone = "zone_%d" % i
			var texte_nom := "%s [%d]" % [nom_zone, i]
			var texte_bornes := "%.0f -> %.0f" % [z.x_debut_px, z.x_fin_px]
			draw_string(font, Vector2(x_min + 12.0, y_min + 26.0), texte_nom, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1, 1, 1, 0.95))
			draw_string(font, Vector2(x_min + 12.0, y_min + 46.0), texte_bornes, HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(font_size - 2, 10), Color(1, 1, 1, 0.82))

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

## Retourne la ZoneDefinition correspondant à la position X, ou la dernière zone.
func zone_en(x: float) -> ZoneDefinition:
	for z: ZoneDefinition in zones:
		if x >= z.x_debut_px and x < z.x_fin_px:
			return z
	return zones.back() if not zones.is_empty() else null

## Retourne l'index dans le tableau zones, ou -1 si vide.
func index_zone_en(x: float) -> int:
	for i: int in range(zones.size()):
		if x >= zones[i].x_debut_px and x < zones[i].x_fin_px:
			return i
	if zones.is_empty():
		return -1
	# À gauche de toutes les zones → zone 0 ; à droite → dernière zone.
	if x < zones[0].x_debut_px:
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

	var x_boss: float = zone_active.x_boss_spawn_px if zone_active.x_boss_spawn_px != 0.0 \
		else zone_active.x_debut_px + (zone_active.x_fin_px - zone_active.x_debut_px) * 0.5
	var pos: Vector2 = Vector2(
		x_boss,
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

	# Jeu gauche→droite : le boss bloque la progression vers la droite.
	if is_instance_valid(_joueur) and _joueur.has_method("set_limite_droite"):
		var limite: float = INF
		if v and zone_active != null:
			limite = zone_active.x_fin_px
		_joueur.call("set_limite_droite", limite)

	emit_signal("avance_bloquee_changee", v)
