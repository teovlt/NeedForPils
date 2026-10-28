class_name Thermos
extends VRPickable
## Thermos de café : on dévisse le bouchon (qui sert de tasse), on se verse un café
## dedans en penchant le thermos au-dessus, puis on le boit (ThermosCup) contre la fatigue.
##
## - Dévisser : en VR, attraper le bouchon avec l'autre main (il reste dans la main,
##   à l'endroit : c'est la tasse). À la souris : clic gauche sur le bouchon. F / A/X sur
##   le thermos fermé : le bouchon se dévisse et tombe à côté.
## - Verser : thermos ouvert penché (goulot vers le bas) : un filet de café coule du bord
##   le plus bas du goulot ; au-dessus de la tasse, il la remplit (sinon, il est perdu).
##   Sans casque : F sur le thermos ouvert verse tout seul dans la tasse si elle est à
##   portée (moins de 1,5 m).
## - Revisser : lâcher la tasse retournée (ou vide) sur le goulot ; ou F sur le thermos
##   ouvert quand la tasse est pleine ou le thermos vide. Le café de la tasse retourne
##   alors dans le thermos.
## Modèle : props/thermos.glb (props/thermos_build.py), nœuds Body et Cup (le bouchon),
## cherchés sous le nœud Model de l'objet.

const THERMOS_GROUP := "thermoses"
const CUP_SCENE := "res://props/items/thermos_cup_item.tscn"
const CUP_TOP := 0.286          # fond de la tasse quand elle est vissée (retournée)
const NECK_TOP := 0.256         # haut du goulot
const NECK_R := 0.019           # rayon intérieur du goulot
const COFFEE := Color(0.2, 0.1, 0.045)
const RATE := 22050

## Café dans le thermos, en tasses.
@export var cups := 4.0
## Débit maximal (tasses par seconde), thermos bien penché.
@export var pour_rate := 0.45

var capped := true
var cup_item: RigidBody3D       # la tasse une fois dévissée

var _cap: Node3D
var _cap_grip: CapGrip
var _stream: MeshInstance3D
var _stream_mesh: CylinderMesh
var _pour_snd: AudioStreamPlayer3D
var _screw_snd: AudioStreamPlayer3D
var _auto_pour := 0.0           # versement automatique (sans casque), secondes restantes
var _pouring := 0.0             # débit actuel (0..1), lu par les tests
var poured_in_cup := 0.0        # total versé dans la tasse (tests)


## Le bouchon : l'attraper le dévisse et le met dans la main (la tasse).
class CapGrip:
	extends VRInteractable
	var thermos
	var _held := {}

	func _ready() -> void:
		highlight_distance = 0.1
		grab_distance = 0.05
		outline_width = 0.002
		pick_bonus = 0.035
		super._ready()

	func _on_grab_begin(hand: Node3D) -> void:
		var g = thermos.unscrew(hand)
		if g:
			_held[hand] = g

	func _on_grab_update(hand: Node3D) -> void:
		var g = _held.get(hand)
		if g and is_instance_valid(g) and not g.is_queued_for_deletion():
			g.grab_update(hand)

	func _on_grab_end(hand: Node3D) -> void:
		var g = _held.get(hand)
		_held.erase(hand)
		if g and is_instance_valid(g) and not g.is_queued_for_deletion():
			g.release(hand)
		thermos.refresh_state()

	func toggle() -> void:
		for h in _held:
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		thermos.toggle()


func _ready() -> void:
	super._ready()
	add_to_group(THERMOS_GROUP)
	friction = 0.5
	var model := item.get_node_or_null("Model")
	_cap = model.find_child("Cup", true, false) as Node3D if model else null
	var body := model.find_child("Body", true, false) as Node3D if model else null
	if body:
		mesh_root = body     # le bouchon a sa propre zone (CapGrip)
	if _cap:
		_cap_grip = CapGrip.new()
		_cap_grip.name = "CapGrip"
		_cap_grip.thermos = self
		_cap_grip.mesh_root = _cap
		item.add_child.call_deferred(_cap_grip)
	# filet de café (cylindre étiré entre le goulot et la tasse)
	_stream = MeshInstance3D.new()
	_stream.name = "CoffeeStream"
	_stream.set_meta("_vr_outline", true)
	_stream_mesh = CylinderMesh.new()
	_stream_mesh.top_radius = 0.0045
	_stream_mesh.bottom_radius = 0.0035
	_stream_mesh.height = 1.0
	_stream_mesh.radial_segments = 6
	_stream_mesh.rings = 1
	_stream.mesh = _stream_mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = COFFEE
	m.roughness = 0.15
	_stream.material_override = m
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.top_level = true
	_stream.visible = false
	item.add_child.call_deferred(_stream)
	_pour_snd = AudioStreamPlayer3D.new()
	_pour_snd.stream = make_pour_sound()
	_pour_snd.unit_size = 1.5
	_pour_snd.volume_db = -8.0
	item.add_child.call_deferred(_pour_snd)
	_screw_snd = AudioStreamPlayer3D.new()
	_screw_snd.stream = make_screw_sound()
	_screw_snd.unit_size = 1.5
	_screw_snd.volume_db = -4.0
	item.add_child.call_deferred(_screw_snd)
	refresh_state.call_deferred()


func refresh_state() -> void:
	if _cap:
		_cap.visible = capped
	if _cap_grip:
		_cap_grip.enabled = capped or _cap_grip.is_grabbed()


## Dévisse le bouchon. hand : la main qui le prend (sinon il tombe à côté). Renvoie le
## Grab de la tasse (ou null).
func unscrew(hand: Node3D) -> VRPickable:
	if not capped:
		return null
	capped = false
	refresh_state()
	_screw_snd.pitch_scale = 1.0
	_screw_snd.play()
	var cup := (load(CUP_SCENE) as PackedScene).instantiate() as RigidBody3D
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(cup)
	cup.global_transform = item.global_transform * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, CUP_TOP, 0))
	cup_item = cup
	var g := cup.get_node("Grab") as VRPickable
	if hand:
		g.grab(hand)
	else:
		# lâchée à côté du thermos, à l'endroit
		cup.global_transform = Transform3D(item.global_basis, item.global_transform * Vector3(0, NECK_TOP + 0.05, 0))
		if storage:
			storage.receive(cup, Vector3.ZERO)
		else:
			CarStorage.throw_free(cup, Vector3.ZERO)
	return g


## Revisse la tasse : le café qu'elle contient retourne dans le thermos.
func screw_on(cup_grab: Node) -> void:
	if capped or cup_grab == null:
		return
	var cup := cup_grab.get_parent() as RigidBody3D
	cups += float(cup_grab.get("fill"))
	var zone := cup.get_parent() as StorageZone
	if zone:
		zone.on_item_taken(cup)
	cup.queue_free()
	cup_item = null
	capped = true
	_auto_pour = 0.0
	refresh_state()
	_screw_snd.pitch_scale = 0.85
	_screw_snd.play()


## Point du goulot d'où coule le café (son bord le plus bas).
func lip_position() -> Vector3:
	var xf := item.global_transform
	var axis := xf.basis.y.normalized()
	var c := xf * Vector3(0, NECK_TOP, 0)
	var down := Vector3.DOWN - axis * Vector3.DOWN.dot(axis)
	if down.length() < 0.01:
		return c
	return c + down.normalized() * NECK_R


func neck_position() -> Vector3:
	return item.global_transform * Vector3(0, NECK_TOP, 0)


## La tasse (Grab) si elle existe encore.
func get_cup() -> ThermosCup:
	if cup_item and is_instance_valid(cup_item) and not cup_item.is_queued_for_deletion():
		return cup_item.get_node_or_null("Grab") as ThermosCup
	cup_item = null
	return null


## F / A/X : dévisse ; ouvert, verse dans la tasse à portée, ou revisse.
func toggle() -> void:
	if capped:
		unscrew(null)
		return
	var cup := get_cup()
	if cup == null or cup.item.global_position.distance_to(item.global_position) > 1.5:
		return
	if cup.fill < 0.95 and cups > 0.01:
		_auto_pour = 3.0
	elif not cup.is_grabbed():
		screw_on(cup)


func _process(delta: float) -> void:
	if item == null:
		return
	var amount := 0.0
	var lip := Vector3.ZERO
	var target: ThermosCup = null
	if not capped and cups > 0.001:
		var cup := get_cup()
		if _auto_pour > 0.0 and cup:
			# sans casque : le café coule du goulot droit dans la tasse
			_auto_pour -= delta
			amount = 1.0
			lip = neck_position()
			target = cup
			if cup.fill >= 0.999:
				_auto_pour = 0.0
		else:
			_auto_pour = 0.0
			var tilt := item.global_basis.y.normalized().dot(Vector3.UP)
			amount = clampf((0.15 - tilt) / 0.5, 0.0, 1.0)
			if amount > 0.0:
				lip = lip_position()
				if cup and cup.can_receive_from(lip):
					target = cup
	_pouring = amount
	if amount <= 0.0:
		_stream.visible = false
		if _pour_snd.playing:
			_pour_snd.stop()
		return
	var q := minf(pour_rate * amount * delta, cups)
	cups -= q
	var end := lip + Vector3.DOWN * 0.45
	if target:
		end = target.liquid_surface()
		poured_in_cup += target.add_coffee(q)
		_pour_snd.pitch_scale = 0.8 + 0.7 * target.fill
	else:
		_pour_snd.pitch_scale = 0.7
	if not _pour_snd.playing:
		_pour_snd.play()
	var v := end - lip
	var seg := maxf(v.length(), 0.005)
	var y := v / seg
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_stream_mesh.top_radius = 0.0045 * sqrt(amount)
	_stream_mesh.bottom_radius = 0.003 * sqrt(amount)
	_stream.global_transform = Transform3D(Basis(x, -y * seg, -z), lip + v * 0.5)
	_stream.visible = true


# --- Sons générés par code ------------------------------------------------------

static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w


## Filet de liquide qui coule (boucle) : bruit filtré + petites bulles.
static func make_pour_sound() -> AudioStreamWAV:
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	var bp := 0.0
	var bubble_t := -1.0
	var bubble_f := 600.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# passe-bande résonant autour de ~1,2 kHz, modulé (glouglou)
		var f := 1200.0 + 500.0 * sin(TAU * 7.0 * t) + 300.0 * sin(TAU * 13.0 * t)
		var k := TAU * f / RATE
		lp += k * bp
		var hp := noise - lp - 0.3 * bp
		bp += k * hp
		var v := bp * 0.5
		if bubble_t < 0.0 and rng.randf() < 0.0009:
			bubble_t = 0.0
			bubble_f = rng.randf_range(500.0, 1100.0)
		if bubble_t >= 0.0:
			v += sin(TAU * bubble_f * (1.0 + bubble_t * 8.0) * bubble_t) * exp(-bubble_t * 60.0) * 0.5
			bubble_t += 1.0 / RATE
			if bubble_t > 0.08:
				bubble_t = -1.0
		# raccord de boucle sans clic
		var edge := clampf(minf(t, 1.0 - t) / 0.02, 0.0, 1.0)
		s[i] = v * lerpf(0.6, 1.0, edge)
	return _wav(s, true)


## Bouchon qu'on visse / dévisse : frottements du filetage.
static func make_screw_sound() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.17, 0.34]:
			var dt: float = t - c
			if dt >= 0.0 and dt < 0.14:
				var env := sin(PI * dt / 0.14)
				v += rng.randf_range(-1.0, 1.0) * env * (0.5 + 0.5 * sin(TAU * 140.0 * dt))
		s[i] = v * 0.5
	return _wav(s)


## Gorgée : « glouk » grave.
static func make_gulp_sound() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 260.0 - 160.0 * minf(t / 0.12, 1.0)
		s[i] = sin(TAU * f * t) * exp(-t * 14.0) * 0.8 * clampf(t / 0.01, 0.0, 1.0)
	return _wav(s)
