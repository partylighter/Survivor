extends VBoxContainer
class_name ApercuPersonnageInventaire

@onready var portrait: TextureRect = $Portrait
@onready var outil_actif: Label = $OutilActif
@onready var outil_secondaire: Label = $OutilSecondaire

var joueur: Player
var gestionnaire_equipement: GestionnaireEquipementJoueur
var texture_reelle: Texture2D

func configurer(nouveau_joueur: Player, nouveau_gestionnaire: GestionnaireEquipementJoueur) -> void:
	joueur = nouveau_joueur
	gestionnaire_equipement = nouveau_gestionnaire
	if gestionnaire_equipement != null and not gestionnaire_equipement.equipement_change.is_connected(actualiser):
		gestionnaire_equipement.equipement_change.connect(actualiser)
	call_deferred(&"actualiser")

func actualiser() -> void:
	if not is_node_ready():
		return
	texture_reelle = _trouver_texture_joueur()
	portrait.texture = texture_reelle
	var actif: Dictionary = gestionnaire_equipement.obtenir_outil_actif() if gestionnaire_equipement != null else {}
	var secondaire: Dictionary = gestionnaire_equipement.obtenir_outil_secondaire() if gestionnaire_equipement != null else {}
	outil_actif.text = "Actif : %s" % String(actif.get("nom", "Aucun"))
	outil_secondaire.text = "Dos : %s" % String(secondaire.get("nom", "Aucun"))

func previsualiser(objet: Dictionary) -> void:
	if portrait != null and objet.get("icone", null) is Texture2D:
		portrait.texture = objet.get("icone") as Texture2D

func retablir_equipement_reel() -> void:
	if portrait != null:
		portrait.texture = texture_reelle

func _trouver_texture_joueur() -> Texture2D:
	if joueur == null:
		return null
	var pile: Array[Node] = [joueur.sprite_joueur if joueur.sprite_joueur != null else joueur]
	while not pile.is_empty():
		var noeud: Node = pile.pop_front()
		if noeud is Sprite2D and (noeud as Sprite2D).texture != null:
			return (noeud as Sprite2D).texture
		if noeud is AnimatedSprite2D:
			var anime: AnimatedSprite2D = noeud as AnimatedSprite2D
			if anime.sprite_frames != null:
				return anime.sprite_frames.get_frame_texture(anime.animation, anime.frame)
		for enfant: Node in noeud.get_children():
			pile.append(enfant)
	return null
