extends VBoxContainer
class_name VueEquipement

var gestionnaire: GestionnaireEquipementJoueur
var grille_slots: GridContainer
var slots: Array[SlotEquipement] = []
var bouton_permuter: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var aide := Label.new()
	aide.text = "Glissez un équipement vers son emplacement.\nClic droit sur un emplacement pour le libérer."
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.modulate = Color(0.72, 0.74, 0.8, 1.0)
	add_child(aide)
	grille_slots = GridContainer.new()
	grille_slots.columns = 2
	grille_slots.add_theme_constant_override("h_separation", 10)
	grille_slots.add_theme_constant_override("v_separation", 10)
	add_child(grille_slots)
	bouton_permuter = Button.new()
	bouton_permuter.text = "Permuter l’outil actif"
	bouton_permuter.pressed.connect(_permuter)
	add_child(bouton_permuter)
	_creer_slots()
	actualiser()

func configurer(nouveau_gestionnaire: GestionnaireEquipementJoueur) -> void:
	if gestionnaire != null and gestionnaire.equipement_change.is_connected(actualiser):
		gestionnaire.equipement_change.disconnect(actualiser)
	gestionnaire = nouveau_gestionnaire
	if gestionnaire != null and not gestionnaire.equipement_change.is_connected(actualiser):
		gestionnaire.equipement_change.connect(actualiser)
	for slot: SlotEquipement in slots:
		slot.configurer(slot.emplacement, gestionnaire)
	actualiser()

func actualiser() -> void:
	for slot: SlotEquipement in slots:
		slot.actualiser()
	if bouton_permuter != null:
		bouton_permuter.disabled = gestionnaire == null or gestionnaire.outils[0].is_empty() or gestionnaire.outils[1].is_empty()

func _creer_slots() -> void:
	for index: int in GestionnaireEquipementJoueur.Emplacement.size():
		var slot := SlotEquipement.new()
		slot.configurer(index as GestionnaireEquipementJoueur.Emplacement, gestionnaire)
		slot.equipement_demande.connect(_equiper)
		slot.desequipement_demande.connect(_desequiper)
		grille_slots.add_child(slot)
		slots.append(slot)

func _equiper(objet: Dictionary, emplacement: GestionnaireEquipementJoueur.Emplacement) -> void:
	if gestionnaire != null:
		gestionnaire.equiper_depuis_inventaire(objet, emplacement)

func _desequiper(emplacement: GestionnaireEquipementJoueur.Emplacement) -> void:
	if gestionnaire != null:
		gestionnaire.desequiper(emplacement)

func _permuter() -> void:
	if gestionnaire != null:
		gestionnaire.permuter_outil_actif()
