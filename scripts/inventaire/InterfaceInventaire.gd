extends CanvasLayer
class_name InterfaceInventaire

@export_node_path("GestionnaireInventaire") var chemin_inventaire: NodePath
@export var touche_ouverture: Key = KEY_I
@export var action_fermer_interface: StringName = &"fermer_interface"

@onready var inventaire: GestionnaireInventaire = get_node_or_null(chemin_inventaire) as GestionnaireInventaire
@onready var gestionnaire_effets_nourriture: GestionnaireEffetsNourriture = get_node_or_null("../GestionnaireEffetsNourriture") as GestionnaireEffetsNourriture
@onready var gestionnaire_equipement: GestionnaireEquipementJoueur = get_node_or_null("../GestionnaireEquipementJoueur") as GestionnaireEquipementJoueur
@onready var gestionnaire_craft: GestionnaireCraftInventaire = get_node_or_null("../GestionnaireCraftInventaire") as GestionnaireCraftInventaire
@onready var interface: Control = $Interface
@onready var grille: GridContainer = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/Defilement/Grille
@onready var etiquette_vide: Label = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/InventaireVide
@onready var etiquette_nombre: Label = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/InfosInventaire
@onready var recherche: LineEdit = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/BarreRechercheTri/Recherche
@onready var tri: OptionButton = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/BarreRechercheTri/Tri
@onready var pile_modes: TabContainer = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneActions/Colonne/PileModes
@onready var vue_equipement: VueEquipement = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneActions/Colonne/PileModes/Equipement
@onready var vue_craft: VueCraftInventaire = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneActions/Colonne/PileModes/Craft
@onready var vue_details: VueDetailsObjet = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneActions/Colonne/PileModes/Details
@onready var apercu_personnage: ApercuPersonnageInventaire = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZonePersonnage/Colonne/ApercuPersonnage

var dialogue_actif: bool = false
var interface_etait_visible_avant_dialogue: bool = false
var interpolation_visibilite_hud: Tween = null
var categorie_active: StringName = &"tous"
var objet_selectionne: Dictionary = {}
var cellules: Array[CelluleInventaire] = []
var groupe_categories: ButtonGroup = ButtonGroup.new()
var groupe_modes: ButtonGroup = ButtonGroup.new()
var boutons_categories: Array[Button] = []
var boutons_modes: Array[Button] = []

func _ready() -> void:
	add_to_group(&"inputs_jeu")
	interface.visible = false
	_connecter_commandes()
	configurer_tri()
	if inventaire != null:
		inventaire.inventaire_change.connect(_rafraichir)
	if gestionnaire_equipement != null:
		gestionnaire_equipement.equipement_change.connect(_rafraichir)
	vue_equipement.configurer(gestionnaire_equipement)
	vue_craft.configurer(gestionnaire_craft)
	vue_details.configurer(gestionnaire_craft.catalogue_recettes if gestionnaire_craft != null else null)
	vue_details.manger_demande.connect(_manger)
	vue_details.equiper_demande.connect(_equiper_depuis_details)
	vue_details.jeter_demande.connect(_jeter_depuis_details)
	vue_details.utiliser_craft_demande.connect(_utiliser_pour_craft)
	vue_details.desassembler_demande.connect(_utiliser_pour_desassemblage)
	apercu_personnage.configurer(get_parent() as Player, gestionnaire_equipement)
	_rafraichir()
	call_deferred(&"_connecter_systeme_dialogue")

func _connecter_commandes() -> void:
	$Interface/Panneau/Marge/Colonne/Entete/Fermer.pressed.connect(fermer_inventaire)
	var barre_categories: HBoxContainer = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneInventaire/Colonne/BarreCategories
	for bouton: Button in barre_categories.get_children():
		bouton.toggle_mode = true
		bouton.button_group = groupe_categories
		bouton.pressed.connect(_changer_categorie.bind(StringName(bouton.get_meta("categorie", "tous"))))
		boutons_categories.append(bouton)
	var barre_modes: HBoxContainer = $Interface/Panneau/Marge/Colonne/HBoxPrincipal/ZoneActions/Colonne/BarreModes
	for index: int in barre_modes.get_child_count():
		var bouton: Button = barre_modes.get_child(index) as Button
		bouton.toggle_mode = true
		bouton.button_group = groupe_modes
		bouton.pressed.connect(_changer_mode.bind(index))
		boutons_modes.append(bouton)
	_changer_categorie(categorie_active)
	_changer_mode(0)
	recherche.text_changed.connect(_quand_recherche_change)
	tri.item_selected.connect(_quand_tri_change)

func configurer_tri() -> void:
	tri.clear()
	tri.add_item("Type")
	tri.add_item("Nom")
	tri.add_item("Quantité")

func _connecter_systeme_dialogue() -> void:
	var systeme_dialogue: SystemeDialogue = get_tree().get_first_node_in_group(&"systeme_dialogue") as SystemeDialogue
	if systeme_dialogue == null:
		return
	if not systeme_dialogue.dialogue_commence.is_connected(_quand_dialogue_commence):
		systeme_dialogue.dialogue_commence.connect(_quand_dialogue_commence)
	if not systeme_dialogue.dialogue_termine.is_connected(_quand_dialogue_termine):
		systeme_dialogue.dialogue_termine.connect(_quand_dialogue_termine)
	if systeme_dialogue.est_dialogue_ouvert():
		_quand_dialogue_commence()

func _quand_dialogue_commence() -> void:
	dialogue_actif = true
	interface_etait_visible_avant_dialogue = interface.visible
	if interface.visible and gestionnaire_craft != null:
		gestionnaire_craft.annuler_craft()
	_changer_visibilite_hud(false)

func _quand_dialogue_termine() -> void:
	dialogue_actif = false
	_changer_visibilite_hud(interface_etait_visible_avant_dialogue)

func _changer_visibilite_hud(doit_afficher: bool) -> void:
	if interpolation_visibilite_hud != null and interpolation_visibilite_hud.is_valid():
		interpolation_visibilite_hud.kill()
	if doit_afficher:
		interface.visible = true
	elif not interface.visible:
		return
	interpolation_visibilite_hud = create_tween()
	interpolation_visibilite_hud.tween_property(interface, "modulate:a", 1.0 if doit_afficher else 0.0, 0.15)
	if not doit_afficher:
		interpolation_visibilite_hud.finished.connect(_masquer_interface_apres_transition)

func _masquer_interface_apres_transition() -> void:
	if dialogue_actif:
		interface.visible = false
		interface.modulate.a = 1.0

func _input(event: InputEvent) -> void:
	if dialogue_actif:
		return
	if interface.visible and event.is_action_pressed(action_fermer_interface):
		fermer_inventaire()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == touche_ouverture:
		if interface.visible:
			fermer_inventaire()
		else:
			ouvrir_inventaire()
		get_viewport().set_input_as_handled()

func ouvrir_inventaire() -> void:
	interface.visible = true
	interface.modulate.a = 1.0
	_rafraichir()

func fermer_inventaire() -> void:
	if gestionnaire_craft != null:
		gestionnaire_craft.annuler_craft()
	interface.visible = false

func objet_correspond_aux_filtres(objet: Dictionary) -> bool:
	var nom: String = String(objet.get("nom", objet.get("identifiant", ""))).to_lower()
	if not recherche.text.strip_edges().is_empty() and not nom.contains(recherche.text.strip_edges().to_lower()):
		return false
	var type_item: int = int(objet.get("type_item", -1))
	match categorie_active:
		&"equipement":
			return type_item == Loot.TypeItem.EQUIPEMENT and not _est_outil(objet)
		&"armes":
			return type_item == Loot.TypeItem.ARME or _est_outil(objet)
		&"consommables":
			return type_item == Loot.TypeItem.CONSO
		&"materiaux":
			return type_item == Loot.TypeItem.MATERIAU or type_item == Loot.TypeItem.UPGRADE
		&"composants":
			return type_item == Loot.TypeItem.COMPOSANT
	return true

func _rafraichir() -> void:
	if grille == null:
		return
	for cellule: CelluleInventaire in cellules:
		grille.remove_child(cellule)
		cellule.queue_free()
	cellules.clear()
	var objets: Array[Dictionary] = []
	if inventaire != null:
		objets = inventaire.obtenir_objets()
	_actualiser_selection_depuis_objets(objets)
	var objets_filtres: Array[Dictionary] = []
	for objet: Dictionary in objets:
		if objet_correspond_aux_filtres(objet):
			objets_filtres.append(objet)
	_trier_objets(objets_filtres)
	for objet: Dictionary in objets_filtres:
		var cellule := CelluleInventaire.new()
		cellule.configurer(objet, _est_objet_equipe(objet))
		cellule.objet_selectionne.connect(_selectionner_objet)
		cellule.objet_double_clique.connect(_utiliser_objet_double_clic)
		cellule.survol_objet.connect(apercu_personnage.previsualiser)
		cellule.fin_survol_objet.connect(apercu_personnage.retablir_equipement_reel)
		grille.add_child(cellule)
		cellules.append(cellule)
	etiquette_vide.visible = objets_filtres.is_empty()
	etiquette_nombre.text = "%d objet(s) affiché(s) · %d au total" % [objets_filtres.size(), objets.size()]
	_reselectionner_cellule()

func _trier_objets(objets: Array[Dictionary]) -> void:
	match tri.selected:
		0:
			objets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _cle_type(a) < _cle_type(b))
		1:
			objets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("nom", "")).naturalnocasecmp_to(String(b.get("nom", ""))) < 0)
		2:
			objets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("quantite", 0)) > int(b.get("quantite", 0)))

func _cle_type(objet: Dictionary) -> String:
	return "%02d_%s" % [int(objet.get("type_item", -1)), String(objet.get("nom", "")).to_lower()]

func _changer_categorie(nouvelle_categorie: StringName) -> void:
	categorie_active = nouvelle_categorie
	for bouton: Button in boutons_categories:
		if StringName(bouton.get_meta("categorie", "tous")) == categorie_active:
			bouton.button_pressed = true
			break
	_rafraichir()

func _quand_recherche_change(_texte: String) -> void:
	_rafraichir()

func _quand_tri_change(_index: int) -> void:
	_rafraichir()

func _changer_mode(index: int) -> void:
	pile_modes.current_tab = index
	if index >= 0 and index < boutons_modes.size():
		boutons_modes[index].button_pressed = true

func _selectionner_objet(objet: Dictionary) -> void:
	objet_selectionne = objet.duplicate(true)
	vue_details.afficher_objet(objet_selectionne)
	_changer_mode(2)
	_reselectionner_cellule()

func _reselectionner_cellule() -> void:
	for cellule: CelluleInventaire in cellules:
		cellule.definir_selectionnee(_meme_objet(cellule.objet, objet_selectionne))

func _actualiser_selection_depuis_objets(objets: Array[Dictionary]) -> void:
	if objet_selectionne.is_empty():
		return
	for objet: Dictionary in objets:
		if _meme_objet(objet, objet_selectionne):
			objet_selectionne = objet.duplicate(true)
			vue_details.afficher_objet(objet_selectionne)
			return
	objet_selectionne.clear()
	vue_details.afficher_objet({})

func _meme_objet(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var donnees_a: Dictionary = a.get("donnees", {})
	var donnees_b: Dictionary = b.get("donnees", {})
	var instance_a: StringName = donnees_a.get("identifiant_instance", &"")
	var instance_b: StringName = donnees_b.get("identifiant_instance", &"")
	if String(instance_a) != "" or String(instance_b) != "":
		return instance_a == instance_b
	return a.get("identifiant", &"") == b.get("identifiant", &"")

func _utiliser_objet_double_clic(objet: Dictionary) -> void:
	if int(objet.get("type_item", -1)) == Loot.TypeItem.CONSO:
		_manger(objet)
	elif _obtenir_donnees_equipement(objet) != null:
		_equiper_depuis_details(objet)

func _manger(objet: Dictionary) -> void:
	if gestionnaire_effets_nourriture == null:
		return
	var definition: LootItemEntry = _obtenir_definition(objet)
	if gestionnaire_effets_nourriture.consommer_nourriture(definition):
		objet_selectionne = {}
		vue_details.afficher_objet({})

func _equiper_depuis_details(objet: Dictionary) -> void:
	if gestionnaire_equipement == null:
		return
	var index: int = gestionnaire_equipement.trouver_emplacement_pour(objet)
	if index >= 0:
		gestionnaire_equipement.equiper_depuis_inventaire(objet, index as GestionnaireEquipementJoueur.Emplacement)
	else:
		_changer_mode(0)

func _jeter_depuis_details(objet: Dictionary) -> void:
	if inventaire == null or int(objet.get("type_item", -1)) != Loot.TypeItem.EQUIPEMENT:
		return
	var donnees: Dictionary = objet.get("donnees", {})
	var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
	var joueur: Node2D = get_parent() as Node2D
	if String(identifiant_instance).is_empty() or joueur == null:
		return
	var direction_jet: Vector2 = joueur.get_global_mouse_position() - joueur.global_position
	if direction_jet.length_squared() <= 0.0001:
		direction_jet = Vector2.RIGHT
	var position_jet: Vector2 = joueur.global_position + direction_jet.normalized() * 600.0
	if inventaire.jeter_equipement(identifiant_instance, position_jet):
		objet_selectionne.clear()
		vue_details.afficher_objet({})

func _utiliser_pour_craft(objet: Dictionary) -> void:
	_changer_mode(1)
	vue_craft.utiliser_pour_assemblage(objet)

func _utiliser_pour_desassemblage(objet: Dictionary) -> void:
	_changer_mode(1)
	vue_craft.utiliser_pour_desassemblage(objet)

func _obtenir_definition(objet: Dictionary) -> LootItemEntry:
	var donnees: Dictionary = objet.get("donnees", {})
	var chemin: String = String(donnees.get("chemin_definition", ""))
	return load(chemin) as LootItemEntry if not chemin.is_empty() else null

func _obtenir_donnees_equipement(objet: Dictionary) -> DonneesEquipement:
	var definition: LootItemEntry = _obtenir_definition(objet)
	return definition.donnees_equipement if definition != null else null

func _est_outil(objet: Dictionary) -> bool:
	var donnees_equipement: DonneesEquipement = _obtenir_donnees_equipement(objet)
	return donnees_equipement != null and donnees_equipement.type_emplacement == TypeEmplacementEquipement.Type.OUTIL

func _est_objet_equipe(objet: Dictionary) -> bool:
	if gestionnaire_equipement == null:
		return false
	for index: int in GestionnaireEquipementJoueur.Emplacement.size():
		if _meme_objet(objet, gestionnaire_equipement.obtenir_objet_equipe(index as GestionnaireEquipementJoueur.Emplacement)):
			return true
	return false
