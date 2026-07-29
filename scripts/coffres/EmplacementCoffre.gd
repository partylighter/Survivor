extends PanelContainer
class_name EmplacementCoffre

signal depot_demande(donnees: Dictionary, type_destination: int, index_destination: int)
signal transfert_rapide_demande(type_source: int, index_source: int, objet: Dictionary, quantite: int)

const TYPE_COFFRE: int = 0
const TYPE_INVENTAIRE: int = 1

@onready var icone: TextureRect = $Marge/Colonne/Icone
@onready var nom_objet: Label = $Marge/Colonne/Nom
@onready var quantite_objet: Label = $Marge/Colonne/Quantite

var type_source: int = TYPE_COFFRE
var index_source: int = -1
var objet: Dictionary = {}
var texte_vide: String = "Vide"

func configurer(nouveau_type_source: int, nouvel_index_source: int, nouvel_objet: Dictionary, nouveau_texte_vide: String = "Vide") -> void:
	type_source = nouveau_type_source
	index_source = nouvel_index_source
	objet = nouvel_objet.duplicate(true)
	texte_vide = nouveau_texte_vide
	_rafraichir()

func _rafraichir() -> void:
	if not is_node_ready():
		return
	var vide: bool = objet.is_empty()
	icone.texture = null if vide else objet.get("icone", null) as Texture2D
	nom_objet.text = texte_vide if vide else String(objet.get("nom", objet.get("identifiant", "")))
	quantite_objet.text = "" if vide else "x%d" % int(objet.get("quantite", 0))
	modulate = Color(0.72, 0.72, 0.75, 1.0) if vide else Color.WHITE

func _get_drag_data(_position_locale: Vector2) -> Variant:
	if objet.is_empty():
		return null
	var apercu := PanelContainer.new()
	var etiquette := Label.new()
	etiquette.text = "%s x%d" % [String(objet.get("nom", objet.get("identifiant", ""))), int(objet.get("quantite", 0))]
	etiquette.add_theme_constant_override("outline_size", 4)
	apercu.add_child(etiquette)
	set_drag_preview(apercu)
	return {
		"origine": type_source,
		"index_source": index_source,
		"objet": objet.duplicate(true)
	}

func _can_drop_data(_position_locale: Vector2, donnees: Variant) -> bool:
	if not donnees is Dictionary:
		return false
	var origine: int = int((donnees as Dictionary).get("origine", -1))
	if origine == TYPE_COFFRE:
		return type_source == TYPE_COFFRE or type_source == TYPE_INVENTAIRE
	if origine == TYPE_INVENTAIRE:
		return type_source == TYPE_COFFRE
	return false

func _drop_data(_position_locale: Vector2, donnees: Variant) -> void:
	if donnees is Dictionary:
		depot_demande.emit((donnees as Dictionary).duplicate(true), type_source, index_source)

func _gui_input(event: InputEvent) -> void:
	if objet.is_empty() or not event is InputEventMouseButton:
		return
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if not clic.pressed:
		return
	if clic.button_index == MOUSE_BUTTON_RIGHT:
		transfert_rapide_demande.emit(type_source, index_source, objet.duplicate(true), 1)
		accept_event()
	elif clic.button_index == MOUSE_BUTTON_LEFT and clic.shift_pressed:
		transfert_rapide_demande.emit(type_source, index_source, objet.duplicate(true), -1)
		accept_event()
