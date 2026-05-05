extends CanvasLayer
class_name BossHealthBarDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false
@export var utiliser_parent_comme_cible: bool = true

@export_node_path("GestionnaireZones") var chemin_zones: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(540.0, 940.0)
@export var auto_position_bas: bool = true
@export var marge_bas_px: float = 72.0
@export var marge_laterale_px: float = 48.0
@export var ui_size: Vector2 = Vector2(840.0, 54.0)
@export var nom_defaut: String = "BOSS"
@export var delai_disparition_desengage_s: float = 2.0
@export_range(8, 64, 1) var taille_nom: int = 22
@export var couleur_nom: Color = Color(1.0, 1.0, 1.0, 0.96)
@export var couleur_fond: Color = Color(0.03, 0.025, 0.025, 0.82)
@export var couleur_bordure: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var couleur_barre: Color = Color(0.86, 0.12, 0.08, 0.96)
@export var couleur_barre_retard: Color = Color(1.0, 0.62, 0.16, 0.55)
@export var vitesse_barre_retard: float = 8.0

var zones_ref: GestionnaireZones = null
var cible: Node2D = null
var sante: Sante = null

var _root: Control = null
var _nom: Label = null
var _cadre: Panel = null
var _fond: ColorRect = null
var _retard: ColorRect = null
var _remplissage: ColorRect = null
var _style_cadre: StyleBoxFlat = null

var _visible_voulu: bool = false
var _hide_t: float = 0.0
var _ratio_retard: float = 1.0

func _ready() -> void:
	_creer_ui()
	_appliquer_style()
	if utiliser_parent_comme_cible and get_parent() is Node2D:
		_changer_cible(get_parent() as Node2D, "")
		if cible != null and cible.has_signal("combat_engage"):
			_set_visible_immediat(false)
		else:
			_set_visible_immediat(cible != null and sante != null)
	else:
		_resoudre_zones()
		_connecter_zones()
		_set_visible_immediat(false)
	set_process(actif)

func set_ui_position(pos: Vector2) -> void:
	auto_position_bas = false
	ui_position = pos
	_appliquer_layout()

func set_bar_position(pos: Vector2) -> void:
	set_ui_position(pos)

func set_bar_size(size: Vector2) -> void:
	ui_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	_appliquer_layout()

func set_auto_bottom_position(active: bool) -> void:
	auto_position_bas = active
	_appliquer_layout()

func afficher_pour(nouvelle_cible: Node2D, nom_boss: String = "") -> void:
	_changer_cible(nouvelle_cible, nom_boss)
	_hide_t = 0.0
	_set_visible_immediat(cible != null and sante != null)

func masquer_apres_delai(delai_s: float = -1.0) -> void:
	_hide_t = max(delai_s if delai_s >= 0.0 else delai_disparition_desengage_s, 0.0)
	if _hide_t <= 0.0:
		_set_visible_immediat(false)

func masquer_maintenant() -> void:
	_hide_t = 0.0
	_set_visible_immediat(false)

func clear_target() -> void:
	_deconnecter_sante()
	_deconnecter_cible_signaux()
	cible = null
	sante = null
	masquer_maintenant()

func _process(dt: float) -> void:
	if not actif:
		return

	if not utiliser_parent_comme_cible and (zones_ref == null or not is_instance_valid(zones_ref)):
		_resoudre_zones()
		_connecter_zones()

	if _hide_t > 0.0:
		_hide_t = max(_hide_t - dt, 0.0)
		if _hide_t <= 0.0:
			_set_visible_immediat(false)

	if sante == null and cible != null and is_instance_valid(cible):
		sante = _resoudre_sante(cible)
		_connecter_sante()

	_appliquer_layout()
	_maj_barre(dt)

func _creer_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_nom = Label.new()
	_nom.name = "NomBoss"
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_nom)

	_cadre = Panel.new()
	_cadre.name = "Cadre"
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cadre)

	_fond = ColorRect.new()
	_fond.name = "Fond"
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.add_child(_fond)

	_retard = ColorRect.new()
	_retard.name = "Retard"
	_retard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.add_child(_retard)

	_remplissage = ColorRect.new()
	_remplissage.name = "Remplissage"
	_remplissage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.add_child(_remplissage)

func _appliquer_style() -> void:
	if _style_cadre == null:
		_style_cadre = StyleBoxFlat.new()

	_style_cadre.bg_color = couleur_fond
	_style_cadre.border_color = couleur_bordure
	_style_cadre.border_width_top = 2
	_style_cadre.border_width_bottom = 2
	_style_cadre.border_width_left = 2
	_style_cadre.border_width_right = 2
	_style_cadre.corner_radius_top_left = 4
	_style_cadre.corner_radius_top_right = 4
	_style_cadre.corner_radius_bottom_left = 4
	_style_cadre.corner_radius_bottom_right = 4
	_cadre.add_theme_stylebox_override("panel", _style_cadre)

	_nom.add_theme_font_size_override("font_size", taille_nom)
	_nom.add_theme_color_override("font_color", couleur_nom)
	_nom.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_nom.add_theme_constant_override("shadow_offset_x", 2)
	_nom.add_theme_constant_override("shadow_offset_y", 2)

	_fond.color = couleur_fond
	_retard.color = couleur_barre_retard
	_remplissage.color = couleur_barre
	_appliquer_layout()

func _appliquer_layout() -> void:
	if _root == null:
		return

	var nom_h: float = maxf(float(taille_nom) + 8.0, 28.0)
	var taille_vue: Vector2 = get_viewport().get_visible_rect().size
	var largeur: float = ui_size.x
	if auto_position_bas:
		largeur = minf(ui_size.x, maxf(taille_vue.x - marge_laterale_px * 2.0, 1.0))
		ui_position = Vector2(
			(taille_vue.x - largeur) * 0.5,
			taille_vue.y - marge_bas_px - ui_size.y - nom_h
		)

	_root.position = ui_position
	_root.size = Vector2(largeur, ui_size.y + nom_h)
	_nom.position = Vector2.ZERO
	_nom.size = Vector2(largeur, nom_h)
	_cadre.position = Vector2(0.0, nom_h)
	_cadre.size = Vector2(largeur, ui_size.y)

	var marge: float = 4.0
	var inner_pos := Vector2(marge, marge)
	var inner_size := Vector2(maxf(largeur - marge * 2.0, 1.0), maxf(ui_size.y - marge * 2.0, 1.0))
	_fond.position = inner_pos
	_fond.size = inner_size
	_retard.position = inner_pos
	_remplissage.position = inner_pos

func _changer_cible(nouvelle_cible: Node2D, nom_boss: String) -> void:
	if cible == nouvelle_cible and is_instance_valid(cible):
		if sante == null or not is_instance_valid(sante):
			sante = _resoudre_sante(cible)
			_connecter_sante()
		_nom.text = _nom_cible(nom_boss)
		_hide_t = 0.0
		_maj_barre(999.0)
		return

	_deconnecter_sante()
	_deconnecter_cible_signaux()
	cible = nouvelle_cible
	sante = _resoudre_sante(cible)
	_ratio_retard = _ratio_sante()
	_nom.text = _nom_cible(nom_boss)
	_connecter_sante()
	_connecter_cible_signaux()
	_maj_barre(999.0)

func _resoudre_sante(n: Node) -> Sante:
	if n == null or not is_instance_valid(n):
		return null
	if n is Enemy:
		var sante_enemy: Sante = (n as Enemy).sante
		if sante_enemy != null and is_instance_valid(sante_enemy):
			return sante_enemy
	var v: Variant = n.get("sante")
	if v is Sante:
		return v as Sante
	var direct := n.get_node_or_null("Sante") as Sante
	if direct != null:
		return direct
	return n.get_node_or_null("Santé") as Sante

func _connecter_sante() -> void:
	if sante == null:
		return
	if not sante.died.is_connected(_on_cible_morte):
		sante.died.connect(_on_cible_morte)
	if not sante.damaged.is_connected(_on_cible_damaged):
		sante.damaged.connect(_on_cible_damaged)

func _deconnecter_sante() -> void:
	if sante == null or not is_instance_valid(sante):
		return
	if sante.died.is_connected(_on_cible_morte):
		sante.died.disconnect(_on_cible_morte)
	if sante.damaged.is_connected(_on_cible_damaged):
		sante.damaged.disconnect(_on_cible_damaged)

func _connecter_cible_signaux() -> void:
	if cible == null or not is_instance_valid(cible):
		return
	if cible.has_signal("combat_engage") and not cible.is_connected("combat_engage", Callable(self, "_on_combat_engage")):
		cible.connect("combat_engage", Callable(self, "_on_combat_engage"))
	if cible.has_signal("combat_desengage") and not cible.is_connected("combat_desengage", Callable(self, "_on_combat_desengage")):
		cible.connect("combat_desengage", Callable(self, "_on_combat_desengage"))

func _deconnecter_cible_signaux() -> void:
	if cible == null or not is_instance_valid(cible):
		return
	if cible.has_signal("combat_engage") and cible.is_connected("combat_engage", Callable(self, "_on_combat_engage")):
		cible.disconnect("combat_engage", Callable(self, "_on_combat_engage"))
	if cible.has_signal("combat_desengage") and cible.is_connected("combat_desengage", Callable(self, "_on_combat_desengage")):
		cible.disconnect("combat_desengage", Callable(self, "_on_combat_desengage"))

func _maj_barre(dt: float) -> void:
	if _remplissage == null or _retard == null:
		return

	var ratio: float = _ratio_sante()
	var cadre_size: Vector2 = _cadre.size if _cadre != null else ui_size
	var inner_w: float = maxf(cadre_size.x - 8.0, 1.0)
	var inner_h: float = maxf(cadre_size.y - 8.0, 1.0)

	if dt >= 100.0:
		_ratio_retard = ratio
	else:
		var a: float = clampf(vitesse_barre_retard * dt, 0.0, 1.0)
		_ratio_retard = lerpf(_ratio_retard, ratio, a)
		if _ratio_retard < ratio:
			_ratio_retard = ratio

	_retard.size = Vector2(inner_w * clampf(_ratio_retard, 0.0, 1.0), inner_h)
	_remplissage.size = Vector2(inner_w * ratio, inner_h)

func _ratio_sante() -> float:
	if sante == null or not is_instance_valid(sante):
		return 0.0
	return clampf(sante.pv / maxf(float(sante.max_pv), 1.0), 0.0, 1.0)

func _nom_cible(nom_boss: String) -> String:
	if not nom_boss.is_empty():
		return nom_boss
	if cible != null and is_instance_valid(cible):
		if cible.has_method("get_boss_nom"):
			return String(cible.call("get_boss_nom"))
		var meta_nom: Variant = cible.get_meta("nom_boss", "")
		if String(meta_nom) != "":
			return String(meta_nom)
		return String(cible.name)
	return nom_defaut

func _set_visible_immediat(v: bool) -> void:
	_visible_voulu = v
	if _root != null:
		_root.visible = v

func _resoudre_zones() -> void:
	zones_ref = get_node_or_null(chemin_zones) as GestionnaireZones
	if zones_ref == null:
		zones_ref = _trouver_zones(get_tree().current_scene)

func _trouver_zones(racine: Node) -> GestionnaireZones:
	if racine == null:
		return null
	if racine is GestionnaireZones:
		return racine as GestionnaireZones
	for enfant in racine.get_children():
		var trouve := _trouver_zones(enfant)
		if trouve != null:
			return trouve
	return null

func _connecter_zones() -> void:
	if zones_ref == null or not is_instance_valid(zones_ref):
		return
	if not zones_ref.boss_spawne.is_connected(_on_boss_spawne):
		zones_ref.boss_spawne.connect(_on_boss_spawne)
	if not zones_ref.boss_mort.is_connected(_on_boss_mort):
		zones_ref.boss_mort.connect(_on_boss_mort)

func _on_boss_spawne(boss: Node2D) -> void:
	_changer_cible(boss, "")
	if boss != null and boss.has_signal("combat_engage"):
		_set_visible_immediat(false)
	else:
		afficher_pour(boss)

func _on_boss_mort() -> void:
	clear_target()

func _on_combat_engage(boss: Node2D) -> void:
	afficher_pour(boss)

func _on_combat_desengage(_boss: Node2D) -> void:
	masquer_apres_delai()

func _on_cible_damaged(_amount: int, _source: Node) -> void:
	_maj_barre(999.0)

func _on_cible_morte() -> void:
	clear_target()

func _dbg(message: String) -> void:
	if debug_enabled:
		print("[BossHealthBarDisplayer] ", message)
