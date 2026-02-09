extends Node

@export var groupe: StringName = &"burn_targets"

@export var burn_duree_s: float = 2.0
@export var burn_depart: float = 0.0
@export var burn_fin: float = 1.0

@export var burn_width: float = 0.08
@export var burn_noise_scale: float = 8.0
@export var burn_flicker: float = 1.8
@export var alpha_cutoff: float = 0.02

@export var burn_pixels_x: int = 160
@export var burn_pixels_y: int = 90

@export var burn_color_inner: Color = Color(1.0, 0.95, 0.25, 1.0)
@export var burn_color_outer: Color = Color(1.0, 0.25, 0.05, 1.0)

var _targets: Array[CanvasItem] = []

func _ready() -> void:
	_targets.clear()

	for n in get_tree().get_nodes_in_group(groupe):
		var ci := n as CanvasItem
		if ci == null:
			continue
		var mat := ci.material as ShaderMaterial
		if mat == null:
			continue
		_targets.append(ci)

	_apply_static_params()
	_set_all(&"burn_amount", burn_depart)
	_burn_anim()

func _apply_static_params() -> void:
	_set_all(&"burn_width", burn_width)
	_set_all(&"burn_noise_scale", burn_noise_scale)
	_set_all(&"burn_flicker", burn_flicker)
	_set_all(&"alpha_cutoff", alpha_cutoff)
	_set_all(&"burn_pixels_x", burn_pixels_x)
	_set_all(&"burn_pixels_y", burn_pixels_y)
	_set_all(&"burn_color_inner", burn_color_inner)
	_set_all(&"burn_color_outer", burn_color_outer)

func _set_all(param: StringName, value) -> void:
	for ci in _targets:
		var mat := ci.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(param, value)

func _burn_anim() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void:
		_set_all(&"burn_amount", v)
	, burn_depart, burn_fin, max(burn_duree_s, 0.01))
