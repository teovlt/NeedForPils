class_name Gun
extends VRPickable
## Pistolet (props/gun/pistol.glb : Body, Slide, Trigger), rangé dans la voiture : on
## tire sur le camping-car des concurrents (Rivals) et sur la police (Pursuer) pour les
## mettre hors d'état de nuire (ils explosent et brûlent sur le bas-côté).
##
## - VR : saisi, il se met dans la main comme un vrai pistolet (crosse dans le poing,
##   canon vers l'avant) ; la gâchette de cette main tire (elle n'accélère / ne freine
##   plus tant qu'on le tient) ; A/X recharge. Un compteur de balles est au dos de la culasse.
## - Souris : il vise là où pointe le curseur ; F (ou clic molette) tire.
## - Une balle touche le véhicule visé si le tir passe dans sa boîte ; une petite aide à
##   la visée (`aim_assist_deg`) pardonne les tirs presque justes, de loin et en roulant.
##   Éclair, recul, traceur, étincelles et « ting » sur la tôle quand ça touche.
## - Chargeur de `magazine` balles, rechargé automatiquement quand il est vide.
## - Partie à deux : le tir est rejoué chez l'autre joueur (Net.rx_call → remote_fire) ;
##   les dégâts sont comptés chez le conducteur, qui décide de la police et des concurrents.

const GUN_GROUP := "guns"
## Bout du canon (repère du modèle).
const MUZZLE := Vector3(0.0, 0.062, -0.168)

@export var magazine := 12
@export var fire_interval := 0.16
@export var range_m := 180.0
## Aide à la visée : angle (degrés) dans lequel un tir raté de peu touche quand même.
@export var aim_assist_deg := 2.5
@export var reload_time := 1.3
## Point de la crosse (repère du modèle) qui se place au centre du poing : sur l'axe de
## la crosse, ~4 cm sous la culasse.
const GRIP_POINT := Vector3(0.0, 0.004, 0.018)
## Main XR Tools en pose « Grip Shaft » (mesurée sur le squelette, repère de la pose
## « grip » OpenXR de la main droite) : doigts repliés vers -X et empilés le long de Y,
## index en haut ; le poing entoure un axe vertical (Y) qui passe vers (-3,2 ; ; -2,8) cm.
## La crosse est posée sur cet axe (redressée de 16° : elle est inclinée dans le modèle),
## la culasse juste au-dessus de l'index, le canon vers l'avant (-Z). Miroir en X pour la
## main gauche. Réglables au casque si besoin.
@export var grip_rotation_deg := Vector3(16.0, 0.0, 0.0)
@export var grip_center := Vector3(-0.032, 0.0, -0.028)

var ammo := 12

var _model: Node3D
var _slide: Node3D
var _slide_rest := Vector3.ZERO
var _trigger_node: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _tracer: MeshInstance3D
var _tracer_t := 0.0
var _counter: Label3D
var _sound: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _cool := 0.0
var _reload_t := 0.0
var _auto_reload := -1.0
var _trig_down := false
var _recoil := 0.0
var _hold_hand: Node3D


func _ready() -> void:
	super._ready()
	add_to_group(GUN_GROUP)
	ammo = magazine
	hand_snap = 1   # poing refermé sur la crosse (voir get_hand_snap)
	_model = item.get_node_or_null("Model") as Node3D
	if _model:
		_slide = _model.find_child("Slide", true, false) as Node3D
		_trigger_node = _model.find_child("Trigger", true, false) as Node3D
		if _slide:
			_slide_rest = _slide.position
	# éclair du canon
	_flash = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.035
	fm.height = 0.09
	fm.radial_segments = 6
	fm.rings = 3
	_flash.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.material_override = mat
	_flash.rotation.x = PI * 0.5
	_flash.position = MUZZLE + Vector3(0, 0, -0.03)
	_flash.visible = false
	_flash.set_meta("_vr_outline", true)
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.light_energy = 3.0
	_flash_light.omni_range = 4.0
	_flash_light.position = MUZZLE
	_flash_light.visible = false
	add_child(_flash_light)
	# traceur (trait lumineux bref jusqu'à l'impact)
	_tracer = MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.012, 0.012, 1.0)
	_tracer.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1.0, 0.9, 0.5, 0.7)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.85, 0.4)
	tmat.emission_energy_multiplier = 4.0
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer.material_override = tmat
	_tracer.top_level = true
	_tracer.visible = false
	_tracer.set_meta("_vr_outline", true)
	_tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tracer)
	# compteur de balles au dos de la culasse (vu par le tireur)
	_counter = Label3D.new()
	_counter.font_size = 40
	_counter.pixel_size = 0.0004
	_counter.outline_size = 6
	_counter.modulate = Color(1.0, 0.85, 0.2)
	_counter.position = Vector3(0, 0.072, 0.0305)
	_counter.set_meta("_vr_outline", true)
	(_slide if _slide else self as Node).add_child(_counter)
	if _slide:
		_counter.position -= _slide.position
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = CombatFx.shot_sound()
	_sound.unit_size = 6.0
	_sound.max_distance = 300.0
	_sound.volume_db = 2.0
	_sound.position = MUZZLE
	add_child(_sound)
	_click = AudioStreamPlayer3D.new()
	_click.unit_size = 2.0
	add_child(_click)
	_update_counter()


## Prise : le pistolet se met dans la main (crosse dans le poing, canon vers l'avant).
func _take(hand: Node3D) -> void:
	super._take(hand)
	_hold_hand = hand
	_trig_down = true   # la gâchette déjà enfoncée à la prise ne tire pas
	if hand is MouseHand:
		_offset = Transform3D(Basis.IDENTITY, Vector3(0.05, -0.06, 0.12))
	else:
		var rot := grip_rotation_deg
		var center := grip_center
		if hand.has_method("is_left") and hand.call("is_left"):
			center.x = -center.x
			rot.y = -rot.y
			rot.z = -rot.z
		var b := Basis.from_euler(rot * (PI / 180.0))
		_offset = Transform3D(b, center - b * GRIP_POINT)


## Main affichée refermée sur la crosse, là où la main tient le pistolet.
func get_hand_snap(hand_xf: Transform3D) -> Variant:
	if item:
		item.global_transform = hand_xf * _offset
	return hand_xf


func _on_grab_update(hand: Node3D) -> void:
	super._on_grab_update(hand)
	if hand != _active_hand:
		return
	if hand is MouseHand and (hand as MouseHand).camera:
		# souris : le canon suit le curseur
		var d := (item.global_position - (hand as MouseHand).camera.global_position).normalized()
		item.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), item.global_position)
	# recul (le pistolet se relève et recule un instant)
	if _model and _recoil > 0.001:
		item.global_transform = item.global_transform * Transform3D(Basis(Vector3.RIGHT, _recoil * 0.22), Vector3(0, 0, _recoil * 0.025))
	# gâchette de la main VR qui le tient
	var v := 0.0
	if hand.has_method("trigger_value"):
		v = float(hand.call("trigger_value"))
	if _trigger_node:
		_trigger_node.rotation.x = -v * 0.35
	if v > 0.7 and not _trig_down:
		_trig_down = true
		pull()
	elif v < 0.3:
		_trig_down = false


func _on_grab_end(hand: Node3D) -> void:
	super._on_grab_end(hand)
	if not is_grabbed():
		_hold_hand = null


## A/X (VR) : recharger ; F / clic molette (souris) : tirer.
func toggle() -> void:
	if not is_grabbed():
		return
	if _hold_hand is MouseHand:
		pull()
	else:
		reload()


## Appui sur la détente.
func pull() -> void:
	if _reload_t > 0.0 or _cool > 0.0:
		return
	if ammo <= 0:
		_click.stream = CombatFx.click_sound(false)
		_click.play()
		reload()
		return
	ammo -= 1
	_cool = fire_interval
	_update_counter()
	var muzzle := item.global_transform * MUZZLE
	var dir := -item.global_basis.z
	_shoot(muzzle, dir, true)
	if ammo == 0:
		_auto_reload = 0.6


func reload() -> void:
	if ammo >= magazine or _reload_t > 0.0:
		return
	_reload_t = reload_time
	_click.stream = CombatFx.click_sound(true)
	_click.play()
	_update_counter()


## Tir rejoué chez l'autre joueur (positions dans le repère de la voiture).
func remote_fire(origin_car: Vector3, dir_car: Vector3) -> void:
	var car := get_tree().get_first_node_in_group(SUV4x4.GROUP) as Node3D
	if car == null:
		return
	_shoot(car.global_transform * origin_car, (car.global_basis * dir_car).normalized(), false)


func _shoot(origin: Vector3, dir: Vector3, local: bool) -> void:
	_sound.pitch_scale = randf_range(0.94, 1.06)
	_sound.play()
	_flash_t = 0.05
	_recoil = 1.0
	if local and _hold_hand and _hold_hand.has_method("pulse"):
		_hold_hand.call("pulse", 1.0, 0.09)
	var hit := find_target(origin, dir)
	var end := origin + dir * range_m
	if not hit.is_empty():
		end = hit["point"]
		var scene := get_tree().current_scene
		CombatFx.sparks(scene, end, -dir)
		CombatFx.play_at(scene, end, CombatFx.ping_sound(), 4.0, 25.0, randf_range(0.9, 1.15))
		if not Net.is_copilot():
			hit["target"].call("take_shot", end)   # le conducteur compte les dégâts
	_show_tracer(origin + dir * 0.05, end)
	if local and Net.is_online() and Net.session and is_instance_valid(Net.session):
		var car := get_tree().get_first_node_in_group(SUV4x4.GROUP) as Node3D
		if car:
			var inv := car.global_transform.affine_inverse()
			Net.rx_call.rpc(String(Net.session.get_parent().get_path_to(self)), "remote_fire", [inv * origin, inv.basis * dir])


## Véhicule touché par un tir : {target, point, dist}, ou {} (rien).
## Les cibles ont get_hit_box() -> [Transform3D du centre, demi-tailles] ou [].
func find_target(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	var assist := cos(deg_to_rad(aim_assist_deg))
	for grp in [Rivals.GROUP, Pursuer.GROUP]:
		for t in get_tree().get_nodes_in_group(grp):
			if not t.has_method("get_hit_box"):
				continue
			var box: Array = t.call("get_hit_box")
			if box.is_empty():
				continue
			var xf: Transform3D = box[0]
			var half: Vector3 = box[1]
			var d := _ray_box(xf, half, origin, dir)
			var point := origin + dir * d
			if d < 0.0:
				# presque juste : visée vers le centre dans l'angle de l'aide à la visée
				var to := xf.origin - origin
				var dist := to.length()
				if dist > range_m or dist < 0.5 or to.normalized().dot(dir) < assist:
					continue
				d = maxf(dist - half.length() * 0.5, 0.5)
				point = xf.origin + (origin - xf.origin).normalized() * minf(half.x, half.z)
			if d <= range_m and d < best_d:
				best_d = d
				best = {"target": t, "point": point, "dist": d}
	return best


## Distance d'entrée du rayon dans la boîte orientée, ou -1.
static func _ray_box(xf: Transform3D, half: Vector3, origin: Vector3, dir: Vector3) -> float:
	var inv := xf.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var tmin := -INF
	var tmax := INF
	for i in 3:
		if absf(d[i]) < 1e-6:
			if o[i] < -half[i] or o[i] > half[i]:
				return -1.0
			continue
		var t1 := (-half[i] - o[i]) / d[i]
		var t2 := (half[i] - o[i]) / d[i]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return -1.0
	return maxf(tmin, 0.0)


func _show_tracer(a: Vector3, b: Vector3) -> void:
	var l := a.distance_to(b)
	if l < 0.1:
		return
	var z := (b - a) / l
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	_tracer.global_transform = Transform3D(Basis(x, z.cross(x), z).scaled(Vector3(1, 1, l)), (a + b) * 0.5)
	_tracer.visible = true
	_tracer_t = 0.05


func _update_counter() -> void:
	if _counter:
		_counter.text = "..." if _reload_t > 0.0 else str(ammo)
		_counter.modulate = Color(1.0, 0.3, 0.2) if ammo <= 3 and _reload_t <= 0.0 else Color(1.0, 0.85, 0.2)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _flash_t > 0.0:
		_flash_t -= delta
	_flash.visible = _flash_t > 0.0
	_flash_light.visible = _flash_t > 0.0
	if _tracer_t > 0.0:
		_tracer_t -= delta
		if _tracer_t <= 0.0:
			_tracer.visible = false
	_recoil = move_toward(_recoil, 0.0, delta * 9.0)
	if _slide:
		_slide.position = _slide_rest + Vector3(0, 0, minf(_recoil * 1.6, 1.0) * 0.022)
	if _auto_reload > 0.0:
		_auto_reload -= delta
		if _auto_reload <= 0.0:
			reload()
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			ammo = magazine
			_update_counter()
