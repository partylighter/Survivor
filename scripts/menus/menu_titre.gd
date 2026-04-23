extends CanvasLayer
class_name MenuTitre

signal demande_jouer
signal demande_parametres
signal demande_credits
signal demande_quitter

@onready var btn_jouer:      TextureButton = %btn_play
@onready var btn_parametres: TextureButton = %btn_settings
@onready var btn_credits:    TextureButton = %btn_credits
@onready var btn_quitter:    TextureButton = %btn_quit

func _ready() -> void:
	btn_jouer.pressed.connect(_on_jouer)
	btn_jouer.add_to_group("droit")
	btn_parametres.pressed.connect(_on_parametres)
	btn_parametres.add_to_group("droit")
	btn_credits.pressed.connect(_on_credits)
	btn_credits.add_to_group("droit")
	btn_quitter.pressed.connect(_on_quitter)
	btn_quitter.add_to_group("droit")

func _on_jouer() -> void:      demande_jouer.emit()
func _on_parametres() -> void: demande_parametres.emit()
func _on_credits() -> void:    demande_credits.emit()
func _on_quitter() -> void:    demande_quitter.emit()
