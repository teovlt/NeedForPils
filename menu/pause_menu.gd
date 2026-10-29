class_name PauseMenu
extends Node3D
## Menu pause en jeu : REPRENDRE, REJOUER, MENU PRINCIPAL.
##
## - VR : bouton menu (☰) de la manette gauche (le bouton de la droite est réservé au
##   système). On vise le panneau avec une manette (trait laser) et on clique à la
##   gâchette.
## - Sans casque : touche P ; on clique à la souris.
## - Seul : le jeu est en pause (voiture, police, physique) et le son baisse.
##   À deux : la partie continue (on ne fige pas l'autre joueur) ; REJOUER relance pour
##   les deux et n'est proposé qu'au conducteur ; MENU PRINCIPAL quitte la partie.
##
## Le pointeur est un simple rayon calculé (pas la physique, arrêtée pendant la pause) :
## il pousse des événements souris dans le SubViewport de l'interface.

const UI_SCENE := preload("res://menu/pause_menu_ui.tscn")
const MENU_SCENE := "res://menu/main_menu.tscn"
const VIEW_SIZE := Vector2i(1200, 820)
## Taille du panneau (m), distance devant les yeux et hauteur sous le regard.
const PANEL_SIZE := Vector2(0.6, 0.41)
const PANEL_DISTANCE := 0.6
const PANEL_DROP := 0.06
const PAUSED_VOLUME_DB := -14.0

var is_open := false

var _viewport: SubViewport
var _ui: Control
var _panel: MeshInstance3D
var _lasers: Array[MeshInstance3D] = []
var _aims: Array[XRController3D] = []
var _menu_down := false
var _trigger_down := [false, false]
var _origin_mode := Node.PROCESS_MODE_INHERIT
var _paused_nodes: Array[Node] = []
var _volume_db := 0.0
var _mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.gui_embed_subwindows = true
	add_child(_viewport)
	_ui = UI_SCENE.instantiate()
	_viewport.add_child(_ui)
	_ui.resume_pressed.connect(close)
	_ui.restart_pressed.connect(_restart)
	_ui.quit_pressed.connect(_quit)
	_panel = MeshInstance3D.new()
	_panel.name = "PausePanel"
	var qm := QuadMesh.new()
	qm.size = PANEL_SIZE
	_panel.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true          # toujours visible, même devant le tableau de bord
	mat.render_priority = 120
	mat.albedo_texture = _viewport.get_texture()
	_panel.material_override = mat
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panel.top_level = true
	_panel.visible = false
	add_child(_panel)


func _exit_tree() -> void:
	if is_open:
		_set_paused(false)


func _process(_delta: float) -> void:
	# bouton menu de la manette gauche (front montant)
	var pressed := false
	for c in _grip_controllers():
		if c.tracker == &"left_hand" and c.get_has_tracking_data() and c.is_button_pressed("menu_button"):
			pressed = true
	if pressed and not _menu_down:
		toggle()
	_menu_down = pressed
	if is_open:
		_update_vr_pointers()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open or _is_vr():
		return
	# souris : rayon depuis la caméra vers le panneau
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var pos: Vector2 = (event as InputEventMouse).position
			var px = _panel_pixel(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
			if px != null:
				var e: InputEventMouse = event.duplicate()
				e.position = px
				e.global_position = px
				_viewport.push_input(e)
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or is_open:
		return
	is_open = true
	_ui.setup(Net.is_online(), Net.is_driver())
	# devant les yeux, accroché au siège (il suit la voiture si elle roule)
	var fwd := -cam.global_basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	fwd = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	var at := cam.global_position + fwd * PANEL_DISTANCE - Vector3.UP * PANEL_DROP
	var holder := cam.get_parent() as Node3D
	_panel.top_level = false
	if holder and _panel.get_parent() != holder:
		_panel.reparent(holder, false)
	_panel.global_transform = Transform3D(Basis.looking_at(at - cam.global_position, Vector3.UP), at)
	_panel.visible = true
	if _is_vr():
		_make_aims()
	else:
		_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_mouse_hands(false)
	if not Net.is_online():
		_set_paused(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	for l in _lasers:
		l.visible = false
	if not _is_vr():
		Input.mouse_mode = _mouse_mode
		_set_mouse_hands(true)
	_set_paused(false)


func _restart() -> void:
	close()
	if Net.is_online():
		Net.restart_game()
	else:
		get_tree().reload_current_scene()


func _quit() -> void:
	close()
	if Net.is_online():
		Net.leave_to_menu()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


# --- Pause (seul) ------------------------------------------------------------------

func _set_paused(paused: bool) -> void:
	if paused == get_tree().paused:
		return
	var origin := _origin()
	if paused:
		# la tête et les manettes continuent de suivre le casque ; les mains, elles,
		# n'attrapent plus rien pendant la pause
		if origin:
			_origin_mode = origin.process_mode
			origin.process_mode = Node.PROCESS_MODE_ALWAYS
			_paused_nodes.clear()
			for n in origin.find_children("*", "Node", true, false):
				if n is VRHandInteractor or n.is_in_group("movement_providers") or n is XRToolsFunctionPickup:
					if n.process_mode == Node.PROCESS_MODE_INHERIT:
						n.process_mode = Node.PROCESS_MODE_PAUSABLE
						_paused_nodes.append(n)
		_volume_db = AudioServer.get_bus_volume_db(0)
		AudioServer.set_bus_volume_db(0, _volume_db + PAUSED_VOLUME_DB)
	else:
		if origin:
			origin.process_mode = _origin_mode
		for n in _paused_nodes:
			if is_instance_valid(n):
				n.process_mode = Node.PROCESS_MODE_INHERIT
		_paused_nodes.clear()
		AudioServer.set_bus_volume_db(0, _volume_db)
	get_tree().paused = paused


# --- Pointeur ----------------------------------------------------------------------

func _is_vr() -> bool:
	var xr := XRServer.primary_interface
	return xr != null and xr.is_initialized()


func _origin() -> XROrigin3D:
	var cam := get_viewport().get_camera_3d()
	return cam.get_parent() as XROrigin3D if cam else null


func _grip_controllers() -> Array:
	var origin := _origin()
	if origin == null:
		return []
	return origin.find_children("*", "XRController3D", false, false).filter(func(c): return c not in _aims)


func _set_mouse_hands(on: bool) -> void:
	for h in get_tree().get_nodes_in_group(MouseHand.GROUP):
		if h is MouseHand:
			(h as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Manettes en pose « aim » (direction de visée) et leur trait laser.
func _make_aims() -> void:
	var origin := _origin()
	if origin == null:
		return
	if _aims.is_empty() or not is_instance_valid(_aims[0]) or _aims[0].get_parent() != origin:
		_aims.clear()
		_lasers.clear()
		for side in [&"left_hand", &"right_hand"]:
			var aim := XRController3D.new()
			aim.name = "PauseAim_" + side
			aim.tracker = side
			aim.pose = &"aim"
			aim.process_mode = Node.PROCESS_MODE_ALWAYS
			origin.add_child(aim)
			_aims.append(aim)
			var laser := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.003, 0.003, 1.0)
			laser.mesh = bm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.72, 0.1)
			m.no_depth_test = true
			m.render_priority = 121
			laser.material_override = m
			laser.visible = false
			aim.add_child(laser)
			_lasers.append(laser)
	_trigger_down = [false, false]


func _update_vr_pointers() -> void:
	for i in _aims.size():
		var aim := _aims[i]
		var laser := _lasers[i]
		if not is_instance_valid(aim) or not aim.get_has_tracking_data():
			laser.visible = false
			continue
		var o := aim.global_position
		var d := -aim.global_basis.z
		var hit = _panel_hit(o, d)
		laser.visible = hit != null
		if hit == null:
			continue
		var dist: float = o.distance_to(hit)
		laser.scale = Vector3(1, 1, dist)
		laser.position = Vector3(0, 0, -dist * 0.5)
		var px: Vector2 = _to_pixel(hit)
		var motion := InputEventMouseMotion.new()
		motion.position = px
		motion.global_position = px
		_viewport.push_input(motion)
		var trig := aim.get_float("trigger") > 0.6
		if trig != _trigger_down[i]:
			_trigger_down[i] = trig
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = trig
			b.position = px
			b.global_position = px
			_viewport.push_input(b)
			if trig:
				aim.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.04, 0.0)


## Point (monde) où le rayon touche le panneau, ou null.
func _panel_hit(o: Vector3, d: Vector3):
	if not _panel.visible:
		return null
	var n := _panel.global_basis.z.normalized()
	var denom := d.dot(n)
	if absf(denom) < 1e-5:
		return null
	var t := (_panel.global_position - o).dot(n) / denom
	if t <= 0.0 or t > 5.0:
		return null
	var p := o + d * t
	var l := _panel.global_transform.affine_inverse() * p
	if absf(l.x) > PANEL_SIZE.x * 0.5 or absf(l.y) > PANEL_SIZE.y * 0.5:
		return null
	return p


func _to_pixel(world: Vector3) -> Vector2:
	var l := _panel.global_transform.affine_inverse() * world
	return Vector2((l.x / PANEL_SIZE.x + 0.5) * VIEW_SIZE.x, (0.5 - l.y / PANEL_SIZE.y) * VIEW_SIZE.y)


func _panel_pixel(o: Vector3, d: Vector3):
	var hit = _panel_hit(o, d)
	return _to_pixel(hit) if hit != null else null
