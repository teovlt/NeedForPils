class_name MouseHand
extends Node3D
## Main virtuelle pilotée à la souris, pour tester sans casque.
##
## - Clic droit maintenu : regarder autour (ou Échap pour capturer/libérer la souris)
## - Survol : le contour de l'objet visé s'illumine (même système que la VR)
## - Clic gauche maintenu : attraper / tirer (portes, volant, leviers, objets...)
## - Molette : rapprocher / éloigner l'objet tenu
## - F ou clic molette : ouvrir/fermer, cran suivant (comme A/X en VR)

const GROUP := "mouse_hands"

@export var camera: Camera3D
## Si défini, la caméra est replacée sur ce noeud à chaque image (ex. siège conducteur).
@export var anchor: Node3D
@export var max_reach := 1.6
@export var look_sensitivity := 0.25
@export var show_help := true

var hovered: VRInteractable
var held: VRInteractable
var _depth := 0.5
var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _help: Label


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if show_help:
		var layer := CanvasLayer.new()
		add_child(layer)
		_help = Label.new()
		_help.text = "Clic gauche : attraper   Clic droit : regarder   Molette : distance   F : ouvrir/fermer"
		_help.add_theme_font_size_override("font_size", 14)
		_help.add_theme_color_override("font_outline_color", Color.BLACK)
		_help.add_theme_constant_override("outline_size", 4)
		_help.position = Vector2(12, 8)
		layer.add_child(_help)
		var cross := Label.new()
		cross.text = "+"
		cross.add_theme_font_size_override("font_size", 20)
		cross.set_anchors_preset(Control.PRESET_CENTER)
		layer.add_child(cross)
		cross.visible = false
		set_meta("crosshair", cross)


## Pour l'interface des objets : pas de vibration à la souris.
func pulse(_amplitude: float, _duration: float) -> void:
	pass


func is_left() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_looking = mb.pressed
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_try_grab()
				else:
					_release()
			MOUSE_BUTTON_WHEEL_UP:
				if held: _depth = clampf(_depth - 0.03, 0.15, max_reach)
			MOUSE_BUTTON_WHEEL_DOWN:
				if held: _depth = clampf(_depth + 0.03, 0.15, max_reach)
			MOUSE_BUTTON_MIDDLE:
				if mb.pressed: _toggle()
	elif event is InputEventMouseMotion:
		if _looking or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var mm := event as InputEventMouseMotion
			_yaw -= mm.relative.x * look_sensitivity * 0.01
			_pitch = clampf(_pitch - mm.relative.y * look_sensitivity * 0.01, -1.4, 1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: _toggle()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
				var cross: Control = get_meta("crosshair", null)
				if cross: cross.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if camera == null:
		return
	var look := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	if anchor:
		camera.global_transform = Transform3D(anchor.global_basis * look, anchor.global_position)
	else:
		camera.basis = look


func _physics_process(_delta: float) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var mouse := get_viewport().get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse = get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if held:
		global_transform = Transform3D(camera.global_basis, origin + dir * _depth)
		if not is_instance_valid(held) or not held.enabled:
			_release()
		else:
			held.grab_update(self)
		return
	# Premier objet interactif touché par le rayon de la souris.
	var best: VRInteractable = null
	var best_t := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var tt := it.ray_hit_distance(origin, dir, max_reach, it.grab_distance * 0.3)
		if tt - it.pick_bonus * 3.0 < best_t - (best.pick_bonus * 3.0 if best else 0.0):
			best = it
			best_t = tt
	if best_t == INF:
		best = null
		best_t = 0.0
	global_transform = Transform3D(camera.global_basis, origin + dir * (best_t if best else 0.6))
	if hovered and hovered != best and is_instance_valid(hovered):
		hovered.set_hand_distance(self, -1.0)
	hovered = best
	if hovered:
		hovered.set_hand_distance(self, 0.0)
		_depth = best_t


func _try_grab() -> void:
	if hovered and not held:
		held = hovered
		hovered.set_hand_distance(self, -1.0)
		hovered = null
		held.grab(self)


func _release() -> void:
	if held and is_instance_valid(held):
		held.release(self)
	held = null


func _toggle() -> void:
	if hovered and hovered.has_method("toggle"):
		hovered.toggle()
