extends CanvasLayer

@export var debug: bool = true

@export var hauteur_px: float = 120.0
@export var duree_s: float = 0.35

@export var top: ColorRect
@export var bottom: ColorRect

var _tween: Tween = null
var _ratio: float = 0.0

func _ready() -> void:
	_p("READY start")

	if top == null or bottom == null:
		push_error("bandes: top/bottom non assignés")
		_p("ERROR: top/bottom null -> stop")
		return

	_p("top=" + top.name + " bottom=" + bottom.name + " hauteur_px=" + str(hauteur_px) + " duree_s=" + str(duree_s))
	_p("viewport size=" + str(get_viewport().get_visible_rect().size))

	_apply(2.0)  # IMPORTANT
	_p("READY end (bars closed). Opening now.")
	ouvrir()

func ouvrir() -> void:
	_p("ouvrir() called")
	_anim_to(0.0)

func fermer() -> void:
	_p("fermer() called")
	_anim_to(1.0)

func _anim_to(target: float) -> void:
	_p("_anim_to target=" + str(target) + " from=" + str(_ratio))

	if _tween != null:
		_p("tween exists running=" + str(_tween.is_running()))
		if _tween.is_running():
			_p("killing tween")
			_tween.kill()

	var dur = max(duree_s, 0.01)
	_p("starting tween duration=" + str(dur))

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply, _ratio, target, dur)

func _apply(r: float) -> void:
	_ratio = clamp(r, 0.0, 1.0)
	var h := hauteur_px * _ratio

	if debug:
		_p("_apply r=" + str(_ratio) + " -> h=" + str(h))

	# TOP
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 0.0
	top.offset_right = 0.0
	top.offset_top = 0.0
	top.offset_bottom = h

	# BOTTOM
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 0.0
	bottom.offset_right = 0.0
	bottom.offset_bottom = 0.0
	bottom.offset_top = -h

	if debug:
		_p("TOP anchors=" + str(top.anchor_left) + "," + str(top.anchor_right) + "," + str(top.anchor_top) + "," + str(top.anchor_bottom)
			+ " offsets LRTB=" + str(top.offset_left) + "," + str(top.offset_right) + "," + str(top.offset_top) + "," + str(top.offset_bottom)
			+ " size=" + str(top.size) + " pos=" + str(top.position))

		_p("BOT anchors=" + str(bottom.anchor_left) + "," + str(bottom.anchor_right) + "," + str(bottom.anchor_top) + "," + str(bottom.anchor_bottom)
			+ " offsets LRTB=" + str(bottom.offset_left) + "," + str(bottom.offset_right) + "," + str(bottom.offset_top) + "," + str(bottom.offset_bottom)
			+ " size=" + str(bottom.size) + " pos=" + str(bottom.position))

func _p(msg: String) -> void:
	if debug:
		print("[Bandes] " + msg)
