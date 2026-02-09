extends Node
class_name GlitchTextureButtonController

enum Etat { IDLE, HOVER, PRESSED }

@export var live_update: bool = false
@export var live_hz: float = 12.0

@export var debug: bool = false
@export var bouton: TextureButton

@export var anim_duree_s: float = 0.10

@export_group("Transform")
@export var pivot_centre: bool = true
@export var anim_transform: bool = true

@export_group("IDLE Transform")
@export var idle_scale: Vector2 = Vector2(1.0, 1.0)
@export var idle_rot_deg: float = 0.0
@export var idle_offset_px: Vector2 = Vector2.ZERO

@export_group("HOVER Transform")
@export var hover_scale: Vector2 = Vector2(1.04, 1.04)
@export var hover_rot_deg: float = 0.6
@export var hover_offset_px: Vector2 = Vector2(0.0, -1.0)

@export_group("PRESSED Transform")
@export var pressed_scale: Vector2 = Vector2(0.97, 0.97)
@export var pressed_rot_deg: float = -0.8
@export var pressed_offset_px: Vector2 = Vector2(0.0, 1.0)

@export_group("IDLE")
@export var idle_glitch_amount: float = 23.16
@export var idle_glitch_speed: float = 1.34
@export var idle_band_count: float = 14.945
@export var idle_rgb_split_px: float = 2.0
@export var idle_max_shift: float = 2.58
@export var idle_jitter_px: float = 1.5
@export var idle_freeze_chance: float = 0.12
@export var idle_blockiness: float = -3.455
@export var idle_scan_strength: float = 0.05
@export var idle_noise_strength: float = 1.71

@export_group("HOVER")
@export var hover_glitch_amount: float = 26.50
@export var hover_glitch_speed: float = 1.55
@export var hover_band_count: float = 18.0
@export var hover_rgb_split_px: float = 2.6
@export var hover_max_shift: float = 3.10
@export var hover_jitter_px: float = 1.9
@export var hover_freeze_chance: float = 0.16
@export var hover_blockiness: float = -2.0
@export var hover_scan_strength: float = 0.065
@export var hover_noise_strength: float = 2.10

@export_group("PRESSED")
@export var pressed_glitch_amount: float = 30.0
@export var pressed_glitch_speed: float = 1.85
@export var pressed_band_count: float = 24.0
@export var pressed_rgb_split_px: float = 3.4
@export var pressed_max_shift: float = 3.75
@export var pressed_jitter_px: float = 2.6
@export var pressed_freeze_chance: float = 0.22
@export var pressed_blockiness: float = -0.5
@export var pressed_scan_strength: float = 0.085
@export var pressed_noise_strength: float = 2.60

var _live_accum: float = 0.0

var _etat: int = Etat.IDLE
var _mat: ShaderMaterial = null
var _tw_shader: Tween = null
var _tw_xform: Tween = null

var _hovered: bool = false
var _down: bool = false

var _base_pos: Vector2
var _base_scale: Vector2
var _base_rot: float

func _ready() -> void:
	if bouton == null:
		push_error("GlitchTextureButtonController: bouton non assigné")
		return

	_mat = bouton.material as ShaderMaterial
	if _mat == null:
		push_error("GlitchTextureButtonController: mets le ShaderMaterial sur 'TextureButton.material' (pas sur la texture)")
		return

	_mat = _mat.duplicate(true) as ShaderMaterial
	bouton.material = _mat

	if pivot_centre:
		bouton.pivot_offset = bouton.size * 0.5

	_base_pos = bouton.position
	_base_scale = bouton.scale
	_base_rot = bouton.rotation

	_connect_signaux()
	_apply_state(Etat.IDLE, true)

func _process(delta: float) -> void:
	if not live_update:
		return
	_live_accum += delta
	var step: float = 1.0 / max(live_hz, 1.0)
	if _live_accum < step:
		return
	_live_accum = 0.0
	_apply_state(_etat, true)

func refresh_now() -> void:
	_apply_state(_etat, true)

func _connect_signaux() -> void:
	if not bouton.mouse_entered.is_connected(_on_enter):
		bouton.mouse_entered.connect(_on_enter, Object.CONNECT_DEFERRED)
	if not bouton.mouse_exited.is_connected(_on_exit):
		bouton.mouse_exited.connect(_on_exit, Object.CONNECT_DEFERRED)
	if not bouton.button_down.is_connected(_on_down):
		bouton.button_down.connect(_on_down, Object.CONNECT_DEFERRED)
	if not bouton.button_up.is_connected(_on_up):
		bouton.button_up.connect(_on_up, Object.CONNECT_DEFERRED)

func _on_enter() -> void:
	_hovered = true
	_update_state()

func _on_exit() -> void:
	_hovered = false
	_update_state()

func _on_down() -> void:
	_down = true
	_update_state()

func _on_up() -> void:
	_down = false
	_update_state()

func _update_state() -> void:
	var next := Etat.IDLE
	if _down:
		next = Etat.PRESSED
	elif _hovered:
		next = Etat.HOVER

	if next == _etat:
		return

	_etat = next
	_apply_state(_etat, false)

func _apply_state(s: int, instant: bool) -> void:
	var dur: float = 0.0 if instant else max(anim_duree_s, 0.01)

	_apply_shader_state(s, dur)
	_apply_transform_state(s, dur)

func _apply_shader_state(s: int, dur: float) -> void:
	if _tw_shader != null and _tw_shader.is_running():
		_tw_shader.kill()
	_tw_shader = null

	var a: float
	var sp: float
	var bc: float
	var rgb: float
	var ms: float
	var jit: float
	var frz: float
	var blk: float
	var sc: float
	var ns: float

	if s == Etat.PRESSED:
		a = pressed_glitch_amount
		sp = pressed_glitch_speed
		bc = pressed_band_count
		rgb = pressed_rgb_split_px
		ms = pressed_max_shift
		jit = pressed_jitter_px
		frz = pressed_freeze_chance
		blk = pressed_blockiness
		sc = pressed_scan_strength
		ns = pressed_noise_strength
	elif s == Etat.HOVER:
		a = hover_glitch_amount
		sp = hover_glitch_speed
		bc = hover_band_count
		rgb = hover_rgb_split_px
		ms = hover_max_shift
		jit = hover_jitter_px
		frz = hover_freeze_chance
		blk = hover_blockiness
		sc = hover_scan_strength
		ns = hover_noise_strength
	else:
		a = idle_glitch_amount
		sp = idle_glitch_speed
		bc = idle_band_count
		rgb = idle_rgb_split_px
		ms = idle_max_shift
		jit = idle_jitter_px
		frz = idle_freeze_chance
		blk = idle_blockiness
		sc = idle_scan_strength
		ns = idle_noise_strength

	if dur <= 0.0:
		_set_params(a, sp, bc, rgb, ms, jit, frz, blk, sc, ns)
		return

	var from_a: float = float(_mat.get_shader_parameter("glitch_amount"))
	var from_sp: float = float(_mat.get_shader_parameter("glitch_speed"))
	var from_bc: float = float(_mat.get_shader_parameter("band_count"))
	var from_rgb: float = float(_mat.get_shader_parameter("rgb_split_px"))
	var from_ms: float = float(_mat.get_shader_parameter("max_shift"))
	var from_jit: float = float(_mat.get_shader_parameter("jitter_px"))
	var from_frz: float = float(_mat.get_shader_parameter("freeze_chance"))
	var from_blk: float = float(_mat.get_shader_parameter("blockiness"))
	var from_sc: float = float(_mat.get_shader_parameter("scan_strength"))
	var from_ns: float = float(_mat.get_shader_parameter("noise_strength"))

	_tw_shader = create_tween()
	_tw_shader.set_trans(Tween.TRANS_QUAD)
	_tw_shader.set_ease(Tween.EASE_OUT)
	_tw_shader.tween_method(func(v: float) -> void:
		var k: float = clamp(v, 0.0, 1.0)
		_set_params(
			lerp(from_a, a, k),
			lerp(from_sp, sp, k),
			lerp(from_bc, bc, k),
			lerp(from_rgb, rgb, k),
			lerp(from_ms, ms, k),
			lerp(from_jit, jit, k),
			lerp(from_frz, frz, k),
			lerp(from_blk, blk, k),
			lerp(from_sc, sc, k),
			lerp(from_ns, ns, k)
		)
	, 0.0, 1.0, dur)

func _apply_transform_state(s: int, dur: float) -> void:
	if not anim_transform:
		return

	if _tw_xform != null and _tw_xform.is_running():
		_tw_xform.kill()
	_tw_xform = null

	var target_scale: Vector2 = idle_scale
	var target_rot: float = deg_to_rad(idle_rot_deg)
	var target_pos: Vector2 = _base_pos + idle_offset_px

	if s == Etat.HOVER:
		target_scale = hover_scale
		target_rot = deg_to_rad(hover_rot_deg)
		target_pos = _base_pos + hover_offset_px
	elif s == Etat.PRESSED:
		target_scale = pressed_scale
		target_rot = deg_to_rad(pressed_rot_deg)
		target_pos = _base_pos + pressed_offset_px

	if dur <= 0.0:
		bouton.scale = target_scale
		bouton.rotation = target_rot
		bouton.position = target_pos
		return

	var from_scale: Vector2 = bouton.scale
	var from_rot: float = bouton.rotation
	var from_pos: Vector2 = bouton.position

	_tw_xform = create_tween()
	_tw_xform.set_trans(Tween.TRANS_QUAD)
	_tw_xform.set_ease(Tween.EASE_OUT)

	_tw_xform.tween_method(func(v: float) -> void:
		var k: float = clamp(v, 0.0, 1.0)
		bouton.scale = from_scale.lerp(target_scale, k)
		bouton.rotation = lerp(from_rot, target_rot, k)
		bouton.position = from_pos.lerp(target_pos, k)
	, 0.0, 1.0, dur)

func _set_params(a: float, sp: float, bc: float, rgb: float, ms: float, jit: float, frz: float, blk: float, sc: float, ns: float) -> void:
	_mat.set_shader_parameter("glitch_amount", a)
	_mat.set_shader_parameter("glitch_speed", sp)
	_mat.set_shader_parameter("band_count", bc)
	_mat.set_shader_parameter("rgb_split_px", rgb)
	_mat.set_shader_parameter("max_shift", ms)
	_mat.set_shader_parameter("jitter_px", jit)
	_mat.set_shader_parameter("freeze_chance", frz)
	_mat.set_shader_parameter("blockiness", blk)
	_mat.set_shader_parameter("scan_strength", sc)
	_mat.set_shader_parameter("noise_strength", ns)

func _log(s: String) -> void:
	if debug:
		print("[GlitchTextureButtonController] " + s)
