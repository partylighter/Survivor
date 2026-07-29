extends CanvasLayer
class_name InterfaceInventaire

@export_node_path("GestionnaireInventaire") var chemin_inventaire: NodePath
@export var touche_ouverture: Key = KEY_I
@export var action_fermer_interface: StringName = &"fermer_interface"

@onready var inventaire: GestionnaireInventaire = get_node_or_null(chemin_inventaire) as GestionnaireInventaire
@onready var gestionnaire_arme: GestionnaireArme = get_node_or_null("../GestionnaireArme") as GestionnaireArme
@onready var interface: Control = $Interface
@onready var grille: GridContainer = $Interface/Panneau/Marge/Colonne/Defilement/Grille
@onready var etiquette_vide: Label = $Interface/Panneau/Marge/Colonne/InventaireVide
@onready var etiquette_equipement: Label = $Interface/Panneau/Marge/Colonne/EquipementMainDroite
@onready var bouton_ranger_arme: Button = $Interface/Panneau/Marge/Colonne/RangerArme
@onready var bouton_fermer: Button = $Interface/Panneau/Marge/Colonne/Fermer

func _ready() -> void:
	add_to_group(&"inputs_jeu")
	interface.visible = false
	bouton_fermer.pressed.connect(fermer_inventaire)
	bouton_ranger_arme.pressed.connect(_ranger_arme)
	if inventaire != null:
		inventaire.inventaire_change.connect(_rafraichir)
	_rafraichir()

func _input(event: InputEvent) -> void:
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
	_rafraichir()

func fermer_inventaire() -> void:
	interface.visible = false

func _rafraichir() -> void:
	if grille == null:
		return
	_actualiser_equipement_main_droite()
	for enfant: Node in grille.get_children():
		grille.remove_child(enfant)
		enfant.queue_free()
	var objets: Array[Dictionary] = inventaire.obtenir_objets() if inventaire != null else []
	etiquette_vide.visible = objets.is_empty()
	for objet: Dictionary in objets:
		grille.add_child(_creer_cellule(objet))

func _creer_cellule(objet: Dictionary) -> Control:
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(160.0, 190.0)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 8)
	marge.add_theme_constant_override("margin_top", 8)
	marge.add_theme_constant_override("margin_right", 8)
	marge.add_theme_constant_override("margin_bottom", 8)
	panneau.add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	marge.add_child(colonne)
	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(64.0, 64.0)
	texture.texture = objet.get("icone", null) as Texture2D
	texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	colonne.add_child(texture)
	var nom := Label.new()
	nom.text = String(objet.get("nom", objet.get("identifiant", "")))
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(nom)
	var quantite := Label.new()
	quantite.text = "x%d" % int(objet.get("quantite", 0))
	quantite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(quantite)
	var type := Label.new()
	type.text = _nom_type(int(objet.get("type_item", -1)))
	type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type.modulate = Color(0.75, 0.75, 0.8, 1.0)
	colonne.add_child(type)
	var donnees: Dictionary = objet.get("donnees", {})
	if int(objet.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT and not donnees.is_empty():
		var qualite := Label.new()
		qualite.text = "Qualite : %s" % String(donnees.get("qualite", "correcte")).capitalize()
		qualite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		colonne.add_child(qualite)
		var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
		if String(identifiant_instance) != "":
			_ajouter_liste_ameliorations(colonne, donnees)
			_ajouter_boutons_ameliorations(colonne, donnees, identifiant_instance)
			var bouton_equiper := Button.new()
			bouton_equiper.text = "Equiper"
			bouton_equiper.disabled = gestionnaire_arme == null or gestionnaire_arme.arme_principale != null
			bouton_equiper.tooltip_text = "Main principale occupee." if gestionnaire_arme != null and gestionnaire_arme.arme_principale != null else "Equipe cette arme dans la main principale."
			bouton_equiper.pressed.connect(_equiper_equipement.bind(identifiant_instance))
			colonne.add_child(bouton_equiper)
	return panneau

func _equiper_equipement(identifiant_instance: StringName) -> void:
	if gestionnaire_arme == null:
		return
	gestionnaire_arme.equiper_equipement_depuis_inventaire(identifiant_instance)
	_rafraichir()

func _ranger_arme() -> void:
	if gestionnaire_arme == null:
		return
	gestionnaire_arme.ranger_arme_principale_dans_inventaire()
	_rafraichir()

func _actualiser_equipement_main_droite() -> void:
	var arme: ArmeBase = gestionnaire_arme.arme_principale if gestionnaire_arme != null else null
	var arme_forge: bool = arme != null and is_instance_valid(arme) and arme.definition_equipement != null and not arme.donnees_instance_forge.is_empty()
	etiquette_equipement.visible = arme_forge
	bouton_ranger_arme.visible = arme_forge
	if not arme_forge:
		return
	var qualite: String = String(arme.donnees_instance_forge.get("qualite", "correcte")).capitalize()
	etiquette_equipement.text = "Main droite : %s | Qualite : %s" % [arme.definition_equipement.nom_affiche, qualite]

func _ajouter_boutons_ameliorations(colonne: VBoxContainer, donnees: Dictionary, identifiant_instance: StringName) -> void:
	if inventaire == null:
		return
	var chemin_definition: String = String(donnees.get("chemin_definition", ""))
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry if not chemin_definition.is_empty() else null
	if definition == null:
		return
	var installees: PackedStringArray = GestionnaireAmeliorationsEquipement.obtenir_ameliorations_installees(donnees)
	for amelioration: AmeliorationForge in definition.ameliorations_forge:
		if amelioration == null or installees.has(amelioration.identifiant):
			continue
		var bouton_installer := Button.new()
		bouton_installer.text = "Installer : %s" % amelioration.nom
		bouton_installer.disabled = inventaire.obtenir_quantite(amelioration.identifiant) < 1
		bouton_installer.pressed.connect(_installer_amelioration.bind(identifiant_instance, amelioration.identifiant))
		colonne.add_child(bouton_installer)

func _ajouter_liste_ameliorations(colonne: VBoxContainer, donnees: Dictionary) -> void:
	var chemin_definition: String = String(donnees.get("chemin_definition", ""))
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry if not chemin_definition.is_empty() else null
	if definition == null:
		return
	var installees: PackedStringArray = GestionnaireAmeliorationsEquipement.obtenir_ameliorations_installees(donnees)
	if installees.is_empty():
		return
	var noms: PackedStringArray = []
	for identifiant: StringName in installees:
		var amelioration: AmeliorationForge = definition.obtenir_amelioration_forge(identifiant)
		noms.append("%s (+%d%% cadence)" % [amelioration.nom, roundi((amelioration.multiplicateur_cadence - 1.0) * 100.0)] if amelioration != null else String(identifiant))
	var liste := Label.new()
	liste.text = "Améliorations : %s" % ", ".join(noms)
	liste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	liste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(liste)

func _installer_amelioration(identifiant_instance: StringName, identifiant_amelioration: StringName) -> void:
	if inventaire == null:
		return
	GestionnaireAmeliorationsEquipement.installer_amelioration(inventaire, identifiant_instance, identifiant_amelioration)
	_rafraichir()

func _nom_type(type_item: int) -> String:
	match type_item:
		Loot.TypeItem.CONSO:
			return "Consommable"
		Loot.TypeItem.UPGRADE:
			return "Amelioration"
		Loot.TypeItem.ARME:
			return "Arme"
		Loot.TypeItem.MATERIAU:
			return "Materiau"
		Loot.TypeItem.COMPOSANT:
			return "Composant"
		Loot.TypeItem.EQUIPEMENT:
			return "Equipement"
		_:
			return "Objet"
