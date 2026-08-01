extends PanelContainer
class_name SlotEquipement

signal equipement_demande(objet: Dictionary, emplacement: GestionnaireEquipementJoueur.Emplacement)
signal desequipement_demande(emplacement: GestionnaireEquipementJoueur.Emplacement)

var emplacement: GestionnaireEquipementJoueur.Emplacement
var gestionnaire: GestionnaireEquipementJoueur
var etiquette_titre: Label
var etiquette_objet: Label
var etiquette_etat: Label

func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 58.0)
	_creer_contenu()
	_actualiser()

func configurer(nouvel_emplacement: GestionnaireEquipementJoueur.Emplacement, nouveau_gestionnaire: GestionnaireEquipementJoueur) -> void:
	emplacement = nouvel_emplacement
	gestionnaire = nouveau_gestionnaire
	if is_node_ready():
		_actualiser()

func peut_recevoir(objet: Dictionary) -> bool:
	return gestionnaire != null and gestionnaire.peut_equiper(objet, emplacement)

func actualiser() -> void:
	_actualiser()

func _can_drop_data(_position: Vector2, donnees: Variant) -> bool:
	var depot: Dictionary = donnees if donnees is Dictionary else {}
	var objet: Dictionary = depot.get("objet", {})
	var compatible: bool = depot.get("origine", &"") == &"inventaire" and peut_recevoir(objet)
	modulate = Color(0.72, 1.15, 0.78, 1.0) if compatible else Color.WHITE
	return compatible

func _drop_data(_position: Vector2, donnees: Variant) -> void:
	modulate = Color.WHITE
	var depot: Dictionary = donnees if donnees is Dictionary else {}
	var objet: Dictionary = depot.get("objet", {})
	if peut_recevoir(objet):
		equipement_demande.emit(objet, emplacement)

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.button_index == MOUSE_BUTTON_RIGHT and evenement.pressed:
		desequipement_demande.emit(emplacement)
		accept_event()

func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE

func _creer_contenu() -> void:
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 10)
	marge.add_theme_constant_override("margin_top", 7)
	marge.add_theme_constant_override("margin_right", 10)
	marge.add_theme_constant_override("margin_bottom", 7)
	add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	marge.add_child(colonne)
	etiquette_titre = Label.new()
	etiquette_titre.add_theme_font_size_override("font_size", 12)
	etiquette_titre.modulate = Color(0.65, 0.68, 0.76, 1.0)
	colonne.add_child(etiquette_titre)
	etiquette_objet = Label.new()
	etiquette_objet.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	colonne.add_child(etiquette_objet)
	etiquette_etat = Label.new()
	etiquette_etat.add_theme_font_size_override("font_size", 10)
	etiquette_etat.modulate = Color(0.48, 0.86, 0.62, 1.0)
	colonne.add_child(etiquette_etat)

func _actualiser() -> void:
	if etiquette_titre == null:
		return
	etiquette_titre.text = gestionnaire.obtenir_nom_emplacement(emplacement) if gestionnaire != null else "Emplacement"
	var objet: Dictionary = gestionnaire.obtenir_objet_equipe(emplacement) if gestionnaire != null else {}
	etiquette_objet.text = String(objet.get("nom", "Vide"))
	var index: int = 0 if emplacement == GestionnaireEquipementJoueur.Emplacement.OUTIL_1 else 1
	var est_outil: bool = emplacement == GestionnaireEquipementJoueur.Emplacement.OUTIL_1 or emplacement == GestionnaireEquipementJoueur.Emplacement.OUTIL_2
	etiquette_etat.visible = est_outil and gestionnaire != null and gestionnaire.index_outil_actif == index and not objet.is_empty()
	etiquette_etat.text = "ACTIF"
	tooltip_text = "Glisser un objet compatible ici. Clic droit pour déséquiper."
