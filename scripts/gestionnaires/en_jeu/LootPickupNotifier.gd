extends CanvasLayer
class_name LootPickupNotifier

@export_node_path("GestionnaireLoot") var chemin_loot: NodePath:
	set(value):
		chemin_loot = value
		_changer_loot_ref(null)
		if is_inside_tree():
			_resoudre_loot_ref(false)

@export var recherche_auto_gestionnaire_loot: bool = true:
	set(value):
		recherche_auto_gestionnaire_loot = value
		if is_inside_tree():
			_changer_loot_ref(null)
			_resoudre_loot_ref(false)

@export var debug_notifications: bool = false:
	set(value):
		debug_notifications = value

@export_group("Disposition")
@export var duree_visible_s: float = 2.6:
	set(value):
		duree_visible_s = maxf(value, 0.05)
		_actualiser_expiration_items()

@export var max_par_ligne: int = 4:
	set(value):
		max_par_ligne = maxi(value, 1)
		_rafraichir_layout_items()

@export var taille_icone: float = 46.0:
	set(value):
		taille_icone = maxf(value, 1.0)
		_rafraichir_layout_items()

@export var espacement: float = 8.0:
	set(value):
		espacement = maxf(value, 0.0)
		_rafraichir_layout_items()

@export var marge_ecran: Vector2 = Vector2(24.0, 24.0):
	set(value):
		marge_ecran = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rafraichir_layout_items()

@export_group("Animation")
@export var duree_entree_s: float = 0.42:
	set(value):
		duree_entree_s = maxf(value, 0.0)

@export var entree_distance_bas_px: float = 110.0:
	set(value):
		entree_distance_bas_px = maxf(value, 0.0)

@export var entree_hauteur_rebond_px: float = 34.0:
	set(value):
		entree_hauteur_rebond_px = maxf(value, 0.0)

@export var duree_deplacement_s: float = 0.18:
	set(value):
		duree_deplacement_s = maxf(value, 0.0)

@export var duree_sortie_s: float = 0.28:
	set(value):
		duree_sortie_s = maxf(value, 0.0)

var loot_ref: GestionnaireLoot = null
var _root: Control = null
var _items: Dictionary = {}
var _ordre: int = 0
var _prochaine_recherche_loot_s: float = 0.0

func _ready() -> void:
	_creer_root()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_resoudre_loot_ref(true)
	set_process(true)

func _process(delta: float) -> void:
	if loot_ref == null or not is_instance_valid(loot_ref):
		var maintenant_recherche: float = _temps_s()
		if maintenant_recherche >= _prochaine_recherche_loot_s:
			_prochaine_recherche_loot_s = maintenant_recherche + 0.5
			_resoudre_loot_ref(false)

	_tick_entrees(delta)

	var maintenant: float = _temps_s()
	var a_sortir: Array[StringName] = []

	for id in _items.keys():
		var data: Dictionary = _items[id]
		if bool(data.get("sortie", false)):
			continue
		if maintenant >= float(data.get("expire", 0.0)):
			a_sortir.append(id)

	for id in a_sortir:
		_sortir_item(id)

func _on_viewport_size_changed() -> void:
	_replacer_items(false)

func _creer_root() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

func _resoudre_loot_ref(log_si_introuvable: bool) -> void:
	var nouvelle_ref: GestionnaireLoot = null

	if chemin_loot != NodePath():
		nouvelle_ref = get_node_or_null(chemin_loot) as GestionnaireLoot

	if nouvelle_ref == null and recherche_auto_gestionnaire_loot:
		var n: Node = get_tree().get_first_node_in_group(&"gestionnaire_loot")
		if n is GestionnaireLoot:
			nouvelle_ref = n as GestionnaireLoot

	_changer_loot_ref(nouvelle_ref)

	if loot_ref != null and is_instance_valid(loot_ref):
		_d("GestionnaireLoot connecte: %s" % loot_ref.get_path())
	elif log_si_introuvable:
		_d("GestionnaireLoot introuvable. Renseigne chemin_loot ou laisse la recherche auto active.")

func _changer_loot_ref(nouvelle_ref: GestionnaireLoot) -> void:
	if loot_ref != null and is_instance_valid(loot_ref) and loot_ref.has_signal("loot_collecte"):
		if loot_ref.loot_collecte.is_connected(_on_loot_collecte):
			loot_ref.loot_collecte.disconnect(_on_loot_collecte)

	loot_ref = nouvelle_ref
	_attacher_signal_loot()

func _attacher_signal_loot() -> void:
	if loot_ref == null or not is_instance_valid(loot_ref):
		return
	if loot_ref.has_signal("loot_collecte") and not loot_ref.loot_collecte.is_connected(_on_loot_collecte):
		loot_ref.loot_collecte.connect(_on_loot_collecte)

func _on_loot_collecte(payload: Dictionary) -> void:
	if not bool(payload.get("afficher_notification_collecte", false)):
		_d("Collecte ignoree: afficher_notification_collecte=false")
		return

	var id: StringName = payload.get("id", payload.get("item_id", &""))
	if String(id) == "":
		_d("Collecte ignoree: id vide")
		return

	var texture: Texture2D = payload.get("icone", null) as Texture2D
	if texture == null:
		_d("Collecte ignoree: icone manquante pour %s" % String(id))
		return

	var quantite: int = maxi(int(payload.get("quantite", 1)), 1)
	_d("Notification collecte: %s x%d" % [String(id), quantite])

	if _items.has(id):
		_actualiser_item(id, quantite)
	else:
		_creer_item(id, texture, quantite, payload)

	_replacer_items(true)

func _creer_item(id: StringName, texture: Texture2D, quantite: int, payload: Dictionary) -> void:
	_ordre += 1

	var panel := Control.new()
	panel.name = "LootPickup_%s" % String(id)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = _get_item_size()
	panel.size = _get_item_size()
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.86, 0.86)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	var icone_rect := TextureRect.new()
	icone_rect.name = "Icone"
	icone_rect.texture = texture
	icone_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icone_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone_rect.custom_minimum_size = Vector2(taille_icone, taille_icone)
	icone_rect.modulate = payload.get("couleur", Color.WHITE)
	box.add_child(icone_rect)

	var label := Label.new()
	label.name = "Compteur"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.95, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(label)

	_root.add_child(panel)

	_items[id] = {
		"control": panel,
		"icone": icone_rect,
		"label": label,
		"count": quantite,
		"expire": _temps_s() + duree_visible_s,
		"ordre": _ordre,
		"sortie": false,
		"nouveau": true,
		"entree_active": false,
		"entree_t": 0.0,
		"entree_cible": Vector2.ZERO
	}

	_mettre_a_jour_label(id)

func _actualiser_item(id: StringName, quantite: int) -> void:
	var data: Dictionary = _items[id]
	data["count"] = int(data.get("count", 0)) + quantite
	data["expire"] = _temps_s() + duree_visible_s
	data["sortie"] = false
	data["ordre"] = _ordre + 1
	_ordre += 1
	_items[id] = data
	_mettre_a_jour_label(id)
	var control: Control = data.get("control") as Control
	if control != null:
		_demarrer_entree(data, control, control.position)
		_items[id] = data

func _mettre_a_jour_label(id: StringName) -> void:
	var data: Dictionary = _items[id]
	var label: Label = data.get("label") as Label
	if label != null:
		label.text = "x%d" % int(data.get("count", 1))

func _replacer_items(anime: bool) -> void:
	if _root == null:
		return

	var ids: Array = []
	for id in _items.keys():
		var data: Dictionary = _items[id]
		if not bool(data.get("sortie", false)):
			ids.append(id)
	ids.sort_custom(func(a, b): return int(_items[a].get("ordre", 0)) < int(_items[b].get("ordre", 0)))

	var total: int = ids.size()
	var par_ligne: int = maxi(max_par_ligne, 1)
	var item_size: Vector2 = _get_item_size()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	for i: int in range(total):
		var id: StringName = ids[i]
		var data: Dictionary = _items[id]
		var depuis_droite: int = total - 1 - i
		var col: int = depuis_droite % par_ligne
		var row: int = floori(float(depuis_droite) / float(par_ligne))
		var cible := Vector2(
			viewport_size.x - marge_ecran.x - item_size.x - float(col) * (item_size.x + espacement),
			viewport_size.y - marge_ecran.y - item_size.y - float(row) * (item_size.y + espacement)
		)

		var control: Control = data.get("control") as Control
		if control == null:
			continue

		if bool(data.get("nouveau", false)):
			data["nouveau"] = false
			_demarrer_entree(data, control, cible)
			_items[id] = data
		elif anime:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(control, "position", cible, duree_deplacement_s)
		else:
			control.position = cible

		if bool(data.get("entree_active", false)):
			data["entree_cible"] = cible
			_items[id] = data

func _rafraichir_layout_items() -> void:
	if _root == null:
		return

	var item_size: Vector2 = _get_item_size()
	for id in _items.keys():
		var data: Dictionary = _items[id]
		var control: Control = data.get("control") as Control
		if control != null:
			control.custom_minimum_size = item_size
			control.size = item_size

		var icone_rect: TextureRect = data.get("icone") as TextureRect
		if icone_rect != null:
			icone_rect.custom_minimum_size = Vector2(taille_icone, taille_icone)

	_replacer_items(false)

func _actualiser_expiration_items() -> void:
	if _items.is_empty():
		return

	var expire: float = _temps_s() + duree_visible_s
	for id in _items.keys():
		var data: Dictionary = _items[id]
		if bool(data.get("sortie", false)):
			continue
		data["expire"] = expire
		_items[id] = data

func _demarrer_entree(data: Dictionary, control: Control, cible: Vector2) -> void:
	if control == null:
		return
	data["entree_active"] = true
	data["entree_t"] = 0.0
	data["entree_cible"] = cible
	control.position = cible + Vector2(0.0, entree_distance_bas_px)
	control.modulate.a = 0.0
	control.scale = Vector2(0.9, 1.08)

func _tick_entrees(delta: float) -> void:
	if _items.is_empty():
		return

	var duree: float = maxf(duree_entree_s, 0.01)
	for id in _items.keys():
		var data: Dictionary = _items[id]
		if not bool(data.get("entree_active", false)):
			continue

		var control: Control = data.get("control") as Control
		if control == null:
			continue

		var t: float = float(data.get("entree_t", 0.0)) + delta
		var u: float = clampf(t / duree, 0.0, 1.0)
		var smooth_u: float = u * u * (3.0 - 2.0 * u)
		var cible: Vector2 = data.get("entree_cible", control.position) as Vector2
		var hauteur_bas: float = entree_distance_bas_px * pow(1.0 - smooth_u, 2.0)
		var impulsion_haut: float = entree_hauteur_rebond_px * sin(PI * smooth_u)

		control.position = cible + Vector2(0.0, hauteur_bas - impulsion_haut)
		control.modulate.a = minf(1.0, u * 4.0)

		var squash: float = sin(PI * u)
		control.scale = Vector2(
			lerpf(0.9, 1.0, smooth_u) + squash * 0.04,
			lerpf(1.08, 1.0, smooth_u) - squash * 0.04
		)

		if u >= 1.0:
			control.position = cible
			control.modulate.a = 1.0
			control.scale = Vector2.ONE
			data["entree_active"] = false

		data["entree_t"] = t
		_items[id] = data

func _sortir_item(id: StringName) -> void:
	if not _items.has(id):
		return

	var data: Dictionary = _items[id]
	data["sortie"] = true
	_items[id] = data

	var control: Control = data.get("control") as Control
	if control == null:
		_items.erase(id)
		_replacer_items(true)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(control, "position", control.position + Vector2(0.0, -18.0), duree_sortie_s)
	tween.tween_property(control, "modulate:a", 0.0, duree_sortie_s)
	tween.tween_property(control, "scale", Vector2(0.92, 0.92), duree_sortie_s)
	tween.finished.connect(func():
		if is_instance_valid(control):
			control.queue_free()
		_items.erase(id)
		_replacer_items(true)
	)

func _temps_s() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _get_item_size() -> Vector2:
	return Vector2(taille_icone, taille_icone + 20.0)

func _d(message: String) -> void:
	if debug_notifications:
		print("[LootPickupNotifier] ", message)
