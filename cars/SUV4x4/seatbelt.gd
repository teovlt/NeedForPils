extends Node3D
## Ceinture de sécurité (une par place). Par défaut : 3 points, conducteur.
## Les autres places réutilisent ce script avec leurs positions (`side` = -1 pour une
## place de droite, `two_point` pour la ceinture ventrale de la place du milieu
## arrière) et `warn` = faux : elles ne déclenchent ni voyant ni carillon.
##
## - Sangle : part du renvoi (D-ring) sur le montant B, passe par la boucle métallique
##   (pêne) et finit à l'ancrage bas, sur le côté extérieur du siège.
## - Débouclée, le pêne pend le long du montant. On le saisit (grip en VR, clic gauche
##   à la souris), on le tire en travers du corps et on l'enfonce dans la boucle, à
##   droite du siège : « clac », la ceinture est mise. Lâché ailleurs, il s'enroule et
##   revient en place.
## - Bouton rouge de la boucle (saisir la boucle, ou A/X / F dessus) : la ceinture se
##   déboucle et s'enroule. A/X ou F sur le pêne : il va se boucler tout seul.
##   Clavier : B.
## - Non bouclée : voyant rouge au combiné ; si on roule (> 10 km/h), carillon (« ding »
##   toutes les 1,4 s) puis, au bout de 20 s, bip rapide continu, comme dans une vraie
##   voiture. Ça s'arrête dès qu'on boucle la ceinture ou qu'on s'arrête.
##
## Toutes les positions sont dans le repère de la voiture (parent).

signal buckled_changed(buckled: bool)

## Sortie de la sangle au renvoi du montant B.
@export var d_ring := Vector3(0.85, 1.60, -0.05)
## Ancrage bas (côté extérieur du siège).
@export var lower_anchor := Vector3(0.716, 0.82, -0.20)
## Entrée de la boucle (fente), à droite du siège, contre le bord intérieur de l'assise,
## à côté du frein à main (qui occupe x 0,14-0,19, z −0,08 à 0,25) : bien visible
## en baissant les yeux vers la droite.
@export var buckle_slot := Vector3(0.222, 0.985, -0.065)
## Trajet de la sangle diagonale bouclée (épaule -> poitrine -> hanche).
@export var shoulder_path := PackedVector3Array([Vector3(0.64, 1.36, -0.15), Vector3(0.46, 1.18, -0.02), Vector3(0.30, 1.02, -0.06)])
## Trajet de la sangle ventrale bouclée (de l'ancrage vers la boucle).
@export var lap_path := PackedVector3Array([Vector3(0.66, 0.97, -0.08), Vector3(0.46, 1.0, -0.03), Vector3(0.30, 0.99, -0.07)])
## Position du pêne au repos, entre le renvoi et l'ancrage (0 = renvoi, 1 = ancrage).
@export_range(0.0, 1.0) var rest_ratio := 0.62
@export var webbing_width := 0.046
## Distance (m) pêne <-> boucle en dessous de laquelle le pêne lâché se boucle.
@export var latch_distance := 0.07
## Longueur max de sangle déroulable depuis le renvoi.
@export var max_reach := 1.25
@export var warn_speed_kmh := 10.0
## Côté de la place : 1 = gauche (renvoi et ancrage côté porte gauche, +X), -1 = droite.
@export var side := 1.0
## Ceinture ventrale 2 points (place du milieu arrière) : pas de renvoi, la sangle va
## de l'ancrage au pêne ; débouclée, le pêne est posé sur l'assise (`rest_point`).
@export var two_point := false
@export var rest_point := Vector3.ZERO
## Yeux de l'occupant (la boucle est tournée vers eux) et inclinaison de la boucle.
@export var eye := Vector3(0.45, 1.45, -0.05)
@export var buckle_up := Vector3(0.12, 1.0, 0.05)
## Voyant et carillon (seulement la ceinture du conducteur).
@export var warn := true
@export var chime_volume := 0.45

var buckled := false
## Temps passé à rouler sans ceinture (secondes), remis à zéro quand on la boucle.
var unbelted_drive_time := 0.0

enum { REST, HELD, RETRACT, AUTO_IN, BUCKLED }
var _state := REST
var _tongue_pos := Vector3.ZERO
var _auto_from := Vector3.ZERO
var _auto_t := 0.0
var _hand: Node3D
var _car: Node3D
var _tongue: VRInteractable
var _buckle: VRInteractable
var _button: Node3D
var _button_rest := Vector3.ZERO
var _web: MeshInstance3D
var _imesh: ImmediateMesh
var _buckle_basis := Basis.IDENTITY
# son
var _player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _rate := 22050.0
var _snd_t := 0.0          # temps dans le motif sonore courant
var _sample_t := 0.0
var _clicks: Array = []    # [temps restant, fréquence] des petits bruits mécaniques
var _chime_mode := 0       # 0 rien, 1 ding lent, 2 bip rapide
var _warn_blink := 0.0


class Grip extends VRInteractable:
	var belt: Node
	var kind := ""
	func _on_grab_begin(h: Node3D) -> void: belt._grip_begin(kind, h)
	func _on_grab_update(h: Node3D) -> void: belt._grip_update(kind, h)
	func _on_grab_end(h: Node3D) -> void: belt._grip_end(kind, h)
	func toggle() -> void: belt._grip_toggle(kind)


func _ready() -> void:
	_car = get_parent() as Node3D
	var parts: Node3D = preload("res://cars/SUV4x4/seatbelt_parts.glb").instantiate()
	add_child(parts)
	# renvoi sur le montant B, face vers l'habitacle (-X)
	var dring := parts.get_node("Belt_DRing") as Node3D
	if two_point:
		dring.queue_free()
	else:
		dring.reparent(self, false)
		dring.transform = Transform3D(_basis_facing(Vector3(-side, 0.0, 0.0), Vector3.UP), d_ring + Vector3(0.016 * side, 0.0, 0.0))
	# ancrage bas sur le flanc du siège, face vers la porte (+X)
	var anchor := parts.get_node("Belt_Anchor") as Node3D
	anchor.reparent(self, false)
	anchor.transform = Transform3D(_basis_facing(Vector3(side, 0.0, 0.0), Vector3(0.0, 1.0, 0.25)), lower_anchor + Vector3(-0.01 * side, -0.012, 0.0))
	# boucle : penchée vers le conducteur, bouton tourné vers ses yeux
	var up := buckle_up.normalized()
	var to_eye := eye - buckle_slot
	_buckle_basis = _basis_facing(to_eye - up * to_eye.dot(up), up)
	_buckle = Grip.new()
	_buckle.name = "Buckle"
	_buckle.belt = self
	_buckle.kind = "buckle"
	_buckle.transform = Transform3D(_buckle_basis, buckle_slot)
	_buckle.highlight_distance = 0.12
	_buckle.grab_distance = 0.06
	_buckle.outline_width = 0.003
	_buckle.pick_bonus = 0.03
	add_child(_buckle)
	var bmesh := parts.get_node("Belt_Buckle") as Node3D
	bmesh.reparent(_buckle, false)
	bmesh.transform = Transform3D.IDENTITY
	_button = parts.get_node("Belt_Button") as Node3D
	_button.reparent(_buckle, false)
	_button_rest = Vector3(0.0, -0.022, 0.014)
	_button.transform = Transform3D(Basis.IDENTITY, _button_rest)
	# pêne
	_tongue = Grip.new()
	_tongue.name = "Tongue"
	_tongue.belt = self
	_tongue.kind = "tongue"
	_tongue.highlight_distance = 0.12
	_tongue.grab_distance = 0.06
	_tongue.outline_width = 0.003
	_tongue.pick_bonus = 0.04
	add_child(_tongue)
	var tmesh := parts.get_node("Belt_Tongue") as Node3D
	tmesh.reparent(_tongue, false)
	tmesh.transform = Transform3D.IDENTITY
	parts.queue_free()
	# sangle (ruban recalculé à chaque image)
	_imesh = ImmediateMesh.new()
	_web = MeshInstance3D.new()
	_web.name = "Webbing"
	_web.mesh = _imesh
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.11, 0.11, 0.12)
	wm.roughness = 0.9
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_web.material_override = wm
	_web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_web)
	# son (carillon, bips, clac)
	_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = 0.1
	_player.stream = gen
	_player.unit_size = 4.0
	_player.max_distance = 20.0
	# carillon : derrière le combiné ; autres places : le clac vient de la boucle
	_player.position = Vector3(0.45, 1.05, 0.75) if warn else buckle_slot
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_tongue_pos = _rest_point()
	_update_visual()


## Base dont +Z = `face` et +Y aussi proche que possible de `up`.
static func _basis_facing(face: Vector3, up: Vector3) -> Basis:
	var z := face.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


func _rest_point() -> Vector3:
	return rest_point if two_point else d_ring.lerp(lower_anchor, rest_ratio)


func _buckled_tongue_point() -> Vector3:
	return buckle_slot + _buckle_basis.y * 0.03


func is_buckled() -> bool:
	return buckled


## 0 : ceinture mise ; 1 : non mise (voyant fixe) ; 2 : non mise en roulant (voyant
## clignotant et carillon).
func get_warning_level() -> int:
	var level: int = _car.get_ignition_level() if _car and _car.has_method("get_ignition_level") else 2
	if buckled or level < 2 or not warn:
		return 0
	return 2 if _chime_mode > 0 else 1


## B au clavier : boucler / déboucler.
func toggle() -> void:
	if buckled:
		_unlatch()
	elif _state != AUTO_IN:
		_start_auto()


# --- Interaction -------------------------------------------------------------

func _grip_begin(kind: String, hand: Node3D) -> void:
	if kind == "tongue":
		if buckled:
			return
		_state = HELD
		_hand = hand
	elif kind == "buckle" and buckled:
		_unlatch()
		if hand.has_method("pulse"):
			hand.pulse(0.4, 0.04)


func _grip_update(kind: String, hand: Node3D) -> void:
	if kind != "tongue" or _state != HELD:
		return
	var p := _car.to_local(hand.global_position)
	# la sangle n'est pas infinie : le pêne reste à portée du renvoi (ou de l'ancrage)
	var origin := lower_anchor if two_point else d_ring
	var reach := max_reach * (0.6 if two_point else 1.0)
	var off := p - origin
	if off.length() > reach:
		p = origin + off.normalized() * reach
	_tongue_pos = p
	if p.distance_to(_buckled_tongue_point()) < 0.025:
		_latch(hand)


func _grip_end(kind: String, hand: Node3D) -> void:
	if kind != "tongue" or _state != HELD:
		return
	_hand = null
	if _tongue_pos.distance_to(_buckled_tongue_point()) < latch_distance or _mouse_aims_buckle(hand):
		_latch(hand)
	else:
		_state = RETRACT


func _grip_toggle(kind: String) -> void:
	if kind == "buckle" and buckled:
		_unlatch()
	elif not buckled and _state != AUTO_IN:
		_start_auto()


## À la souris, la profondeur est difficile à régler : on boucle aussi si la souris
## vise la boucle au moment où on lâche.
func _mouse_aims_buckle(hand: Node3D) -> bool:
	if hand == null or not hand.is_in_group("mouse_hands"):
		return false
	var cam: Camera3D = hand.get("camera")
	if cam == null:
		return false
	var o := cam.global_position
	var d := (hand.global_position - o).normalized()
	var b := _car.to_global(_buckled_tongue_point())
	var along := (b - o).dot(d)
	return along > 0.0 and (o + d * along).distance_to(b) < 0.05


func _start_auto() -> void:
	_state = AUTO_IN
	_auto_from = _tongue_pos
	_auto_t = 0.0


func _latch(hand: Node3D = null) -> void:
	_state = BUCKLED
	buckled = true
	unbelted_drive_time = 0.0
	_tongue.enabled = false   # la main qui le tenait le lâche
	_tongue_pos = _buckled_tongue_point()
	_clicks.append([0.035, 1900.0])
	_clicks.append([0.02, 3200.0])
	if hand and hand.has_method("pulse"):
		hand.pulse(0.7, 0.06)
	buckled_changed.emit(true)


func _unlatch() -> void:
	buckled = false
	_state = RETRACT
	_tongue.enabled = true
	_clicks.append([0.03, 1400.0])
	var tw := create_tween()
	tw.tween_property(_button, "position", _button_rest - Vector3(0, 0, 0.004), 0.06)
	tw.tween_property(_button, "position", _button_rest, 0.12)
	buckled_changed.emit(false)


# --- Mise à jour ---------------------------------------------------------------

func _process(delta: float) -> void:
	match _state:
		RETRACT:
			_tongue_pos = _tongue_pos.move_toward(_rest_point(), 2.2 * delta)
			if _tongue_pos.is_equal_approx(_rest_point()):
				_state = REST
				_clicks.append([0.015, 900.0])
		AUTO_IN:
			_auto_t = minf(_auto_t + delta / 0.9, 1.0)
			var k := smoothstep(0.0, 1.0, _auto_t)
			# passe devant le torse (comme une main qui tire la sangle)
			var mid := ((lap_path[1] if two_point else shoulder_path[1]) + Vector3(0.0, 0.0, 0.12))
			var a := _auto_from.lerp(mid, k)
			var b := mid.lerp(_buckled_tongue_point(), k)
			_tongue_pos = a.lerp(b, k)
			if _auto_t >= 1.0:
				_latch()
		BUCKLED:
			_tongue_pos = _buckled_tongue_point()
	_update_warning(delta)
	_update_visual()
	_fill_audio()


func _update_warning(delta: float) -> void:
	var kmh := absf(float(_car.get("forward_speed"))) * 3.6 if _car else 0.0
	var level: int = _car.get_ignition_level() if _car and _car.has_method("get_ignition_level") else 2
	if buckled or level < 2 or not warn:
		_chime_mode = 0   # ceinture mise, contact coupé, ou place sans alerte
		return
	if kmh > warn_speed_kmh or (_chime_mode > 0 and kmh > 5.0):
		unbelted_drive_time += delta
		var mode := 1 if unbelted_drive_time < 20.0 else 2
		if mode != _chime_mode:
			_snd_t = 0.0
		_chime_mode = mode
	else:
		_chime_mode = 0


func _update_visual() -> void:
	# orientation du pêne : tiré par la sangle vers le renvoi ; aligné sur la boucle tout près
	var inward := Vector3(-side, 0.0, 0.0)
	var hang: Basis
	if two_point:
		# posé à plat sur l'assise, tiré vers l'ancrage
		var to_a := lower_anchor - _tongue_pos
		hang = _basis_facing(Vector3.UP, to_a if to_a.length() > 0.01 else Vector3.FORWARD)
	else:
		var to_d := (d_ring - _tongue_pos)
		hang = _basis_facing(inward, to_d if to_d.length() > 0.01 else Vector3.UP)
	var near := clampf(1.0 - _tongue_pos.distance_to(_buckled_tongue_point()) / 0.15, 0.0, 1.0)
	var b := hang.slerp(_buckle_basis, near) if near > 0.0 else hang
	_tongue.transform = Transform3D(b, _tongue_pos)
	# sangle
	_imesh.clear_surfaces()
	var body_n := Vector3(0.0, 0.35, 1.0).normalized()
	if buckled:
		if not two_point:
			var sh := PackedVector3Array([d_ring])
			sh.append_array(shoulder_path)
			sh.append(_tongue_pos)
			_ribbon(sh, [inward, body_n, body_n, body_n, body_n])
		var lap := PackedVector3Array([lower_anchor])
		lap.append_array(lap_path)
		lap.append(_tongue_pos)
		_ribbon(lap, [Vector3(0, 1, 0.3).normalized(), body_n, body_n, body_n, body_n])
	elif two_point:
		_ribbon(PackedVector3Array([lower_anchor, _tongue_pos]), [Vector3.UP, Vector3.UP])
	else:
		_ribbon(PackedVector3Array([d_ring, _tongue_pos]), [inward, inward])
		_ribbon(PackedVector3Array([_tongue_pos, lower_anchor]), [inward, inward])


## Ruban plat le long d'une polyligne ; `normals` = face de la sangle à chaque point.
func _ribbon(pts: PackedVector3Array, normals: Array) -> void:
	if pts.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var prev_side := Vector3.ZERO
	for i in pts.size():
		var t := Vector3.ZERO
		if i > 0:
			t += (pts[i] - pts[i - 1]).normalized()
		if i < pts.size() - 1:
			t += (pts[i + 1] - pts[i]).normalized()
		var n: Vector3 = normals[mini(i, normals.size() - 1)]
		var side := t.cross(n)
		if side.length_squared() < 1e-6:
			side = prev_side if prev_side != Vector3.ZERO else Vector3.FORWARD
		side = side.normalized()
		if prev_side != Vector3.ZERO and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		var nn := side.cross(t).normalized()
		var hw := side * webbing_width * 0.5
		# le pêne et la boucle sont moins larges que la sangle : on la serre aux bouts
		_imesh.surface_set_normal(nn)
		_imesh.surface_add_vertex(pts[i] - hw)
		_imesh.surface_set_normal(nn)
		_imesh.surface_add_vertex(pts[i] + hw)
	_imesh.surface_end()


# --- Son -----------------------------------------------------------------------

func _fill_audio() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var dt := 1.0 / _rate
	for i in frames:
		var s := 0.0
		if _chime_mode == 1:
			# « ding » doux toutes les 1,4 s : deux partiels qui s'éteignent
			var ph := fmod(_snd_t, 1.4)
			var env := exp(-ph * 5.0) * minf(ph * 400.0, 1.0)
			s += (sin(TAU * 880.0 * _snd_t) + 0.35 * sin(TAU * 1760.0 * _snd_t)) * env * 0.5
		elif _chime_mode == 2:
			# bip rapide : 0,12 s allumé / 0,13 s éteint, plus aigu et plus sec
			var ph2 := fmod(_snd_t, 0.25)
			if ph2 < 0.12:
				var e2 := minf(ph2 * 300.0, 1.0) * minf((0.12 - ph2) * 300.0, 1.0)
				s += (1.0 if sin(TAU * 2000.0 * _snd_t) > 0.0 else -1.0) * 0.28 * e2
		_snd_t += dt
		# clics mécaniques (pêne qui entre dans la boucle, bouton, enrouleur)
		var j := 0
		while j < _clicks.size():
			var c: Array = _clicks[j]
			var rem: float = c[0]
			if rem <= 0.0:
				_clicks.remove_at(j)
				continue
			var noise := randf() * 2.0 - 1.0
			s += (noise * 0.6 + sin(TAU * float(c[1]) * rem) * 0.4) * clampf(rem * 30.0, 0.0, 1.0) * 0.9
			c[0] = rem - dt
			j += 1
		var out := clampf(s * chime_volume, -1.0, 1.0)
		_playback.push_frame(Vector2(out, out))
