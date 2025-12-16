extends Node2D
class_name LootAnim

@export var chemin_visuel: NodePath
@export var chemin_particules_aimant: NodePath
@export var chemin_particules_collecte: NodePath
@export var chemin_son_collecte: NodePath

@export var amplitude_flottement_px: float = 3.0
@export var frequence_flottement_hz: float = 2.0
@export var amplitude_breath: float = 0.04
@export var frequence_breath_hz: float = 1.2

@export var force_suivi_rotation: float = 18.0
@export var etirement_max: float = 0.18

@export var punch_scale: float = 1.18
@export var punch_duree_in_s: float = 0.08
@export var punch_duree_out_s: float = 0.10

var _t_idle: float = 0.0
var _graine: float = 0.0

var _scale_base: Vector2 = Vector2.ONE
var _pos_base: Vector2 = Vector2.ZERO
var _modulate_base: Color = Color(1, 1, 1, 1)

@onready var visuel: Node2D = get_node_or_null(chemin_visuel) as Node2D
@onready var particules_aimant: Node = get_node_or_null(chemin_particules_aimant)
@onready var particules_collecte: Node = get_node_or_null(chemin_particules_collecte)
@onready var son_collecte: Node = get_node_or_null(chemin_son_collecte)

func _ready() -> void:
	_graine = randf() * TAU

	if visuel == null:
		visuel = self

	_scale_base = visuel.scale
	_pos_base = visuel.position

	if visuel is CanvasItem:
		_modulate_base = (visuel as CanvasItem).modulate


func maj_idle(delta: float) -> void:
	_t_idle += delta

	var t1: float = (_t_idle * TAU * frequence_flottement_hz) + _graine
	var t2: float = (_t_idle * TAU * frequence_breath_hz) + (_graine * 0.37)

	var bob_y: float = sin(t1) * amplitude_flottement_px
	visuel.position = _pos_base + Vector2(0.0, bob_y)

	var breath: float = 1.0 + (sin(t2) * amplitude_breath)
	visuel.scale = _scale_base * Vector2(breath, breath)

	visuel.rotation = 0.0

func on_debut_aimant() -> void:
	if particules_aimant != null and particules_aimant.has_method("restart"):
		particules_aimant.call("restart")

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(visuel, "scale", _scale_base * punch_scale, punch_duree_in_s)
	tw.tween_property(visuel, "scale", _scale_base, punch_duree_out_s)

func maj_aimant(vitesse: Vector2, delta: float) -> void:
	visuel.position = _pos_base

	if vitesse.length_squared() > 4.0:
		var angle_cible: float = vitesse.angle()
		var k: float = 1.0 - exp(-force_suivi_rotation * delta)
		visuel.rotation = lerp_angle(visuel.rotation, angle_cible, k)

	var v01: float = clamp(vitesse.length(), 0.0, 1.0)

	var sx: float = 1.0 + (etirement_max * v01)
	var sy: float = 1.0 - (etirement_max * 0.7 * v01)

	var scale_cible: Vector2 = _scale_base * Vector2(sx, sy)
	visuel.scale = visuel.scale.lerp(scale_cible, float(1.0 - exp(-22.0 * delta)))

func jouer_collecte(noeud_loot: Node2D, pos_fin: Vector2, duree_s: float, fin: Callable) -> void:
	if particules_collecte != null and particules_collecte.has_method("restart"):
		particules_collecte.call("restart")
	if son_collecte != null and son_collecte.has_method("play"):
		son_collecte.call("play")

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_EXPO)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(noeud_loot, "global_position", pos_fin, duree_s)

	if visuel is CanvasItem:
		var c: Color = _modulate_base
		c.a = 0.0
		tw.tween_property(visuel as CanvasItem, "modulate", c, duree_s)

	tw.tween_property(visuel, "scale", Vector2.ZERO, duree_s)

	tw.finished.connect(func() -> void:
		if fin.is_valid():
			fin.call()
	)
