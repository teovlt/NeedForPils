class_name Grinder
extends VRPickable
## Grinder à herbe (props/rolling/grinder.glb : Base, Lid).
##
## - A/X (main qui le tient) ou F : ouvre / ferme le couvercle (il bascule sur le côté).
## - Ouvert : lâcher une tête de weed (RollItem « bud ») au-dessus de la chambre -> elle
##   tombe dedans (4 au plus).
## - Fermé avec des têtes : en VR, attraper le couvercle avec l'autre main et le tourner
##   (un tour et demi) ; ou A/X / F : il moud tout seul. Ça craque, les têtes deviennent
##   de l'herbe moulue (1 tête = de quoi rouler un joint bien chargé).
## - Ouvert avec de l'herbe moulue : l'autre main (grip, ou bout de l'index à la gâchette)
##   en prend une pincée (RollItem « weed ») à lâcher sur une feuille (RollingSheet).
## - Tenu dans une main : l'autre main n'a accès qu'au couvercle et à l'herbe.

const BASE_H := 0.028
const CH_R := 0.025
const CH_FLOOR := 0.006
const GR_R := 0.03
const PINCH_SCENE := "res://props/items/pinch_item.tscn"
const BUD_MODEL := "res://props/rolling/bud.glb"
const MAX_BUDS := 4
const PINCH := 0.34
const RATE := 22050

@export var open := false

var buds := 0
var ground := 0.0
var grind_progress := 0.0
var grinds := 0                 # tests

var _lid: Node3D
var _hinge: Node3D
var _bud_nodes: Array[Node3D] = []
var _ground_mi: MeshInstance3D
var _ground_mesh: CylinderMesh
var _lid_grip: LidGrip
var _taker: GroundTaker
var _crunch: AudioStreamPlayer3D
var _snap: AudioStreamPlayer3D
var _auto_grind := 0.0
var _built_g := false


## Couvercle à tourner (VR, grinder fermé avec des têtes dedans).
class LidGrip:
	extends VRInteractable
	var grinder
	var _ref := {}

	func _ready() -> void:
		highlight_distance = 0.08
		grab_distance = 0.05
		outline_width = 0.0015
		pick_bonus = 0.03
		super._ready()

	func _twist(hand: Node3D) -> Vector3:
		var b: Basis = grinder.item.global_basis.orthonormalized()
		var v := b.inverse() * hand.global_basis.x
		v.y = 0.0
		return v.normalized() if v.length_squared() > 1e-4 else Vector3.RIGHT

	func _on_grab_begin(hand: Node3D) -> void:
		_ref[hand] = _twist(hand)

	func _on_grab_update(hand: Node3D) -> void:
		var r := _twist(hand)
		var last: Vector3 = _ref.get(hand, r)
		_ref[hand] = r
		var d := atan2(last.cross(r).y, last.dot(r))
		grinder.turn_lid(d, hand)

	func _on_grab_end(hand: Node3D) -> void:
		_ref.erase(hand)
		grinder.stop_crunch()

	func toggle() -> void:
		grinder.toggle()


## Herbe moulue dans la chambre ouverte : en prend une pincée.
class GroundTaker:
	extends VRInteractable
	var grinder
	var _held := {}

	func _ready() -> void:
		highlight_distance = 0.1
		grab_distance = 0.05
		outline_width = 0.0012
		pick_bonus = 0.035
		grab_with_trigger = true
		super._ready()

	func _on_grab_begin(hand: Node3D) -> void:
		var g = grinder.take_pinch_into(hand)
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
		grinder.refresh_state()


func _ready() -> void:
	super._ready()
	add_to_group(RECEIVERS)
	rest_up_axis = 1
	friction = 0.6
	_build.call_deferred()


func _build() -> void:
	if _built_g:
		return
	_built_g = true
	var model := item.get_node_or_null("Model")
	_lid = model.find_child("Lid", true, false) as Node3D if model else null
	var base := model.find_child("Base", true, false) as Node3D if model else null
	if _lid == null or base == null:
		push_warning("Grinder : nœuds Lid / Base introuvables")
		return
	# charnière fictive sur le bord : le couvercle bascule sur le côté pour ouvrir
	_hinge = Node3D.new()
	_hinge.name = "LidHinge"
	_hinge.position = Vector3(-GR_R, BASE_H, 0)
	base.get_parent().add_child(_hinge)
	var lxf := _lid.global_transform
	_lid.get_parent().remove_child(_lid)
	_hinge.add_child(_lid)
	_lid.global_transform = lxf
	# têtes dans la chambre
	var bud_scene := load(BUD_MODEL) as PackedScene
	for i in MAX_BUDS:
		var b := bud_scene.instantiate() as Node3D
		b.scale = Vector3.ONE * 0.75
		var a := TAU * i / MAX_BUDS
		b.position = Vector3(cos(a) * 0.011, CH_FLOOR + 0.007, sin(a) * 0.011)
		b.rotation = Vector3(PI * 0.5, a, 0.0)
		b.visible = false
		base.add_child(b)
		_bud_nodes.append(b)
	# herbe moulue (disque vert dont l'épaisseur suit la quantité)
	_ground_mi = MeshInstance3D.new()
	_ground_mi.name = "Ground"
	_ground_mesh = CylinderMesh.new()
	_ground_mesh.top_radius = CH_R - 0.0012
	_ground_mesh.bottom_radius = CH_R - 0.0012
	_ground_mesh.radial_segments = 14
	_ground_mesh.rings = 1
	_ground_mi.mesh = _ground_mesh
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.42, 0.19)
	gm.roughness = 0.95
	_ground_mi.material_override = gm
	base.add_child(_ground_mi)
	_lid_grip = LidGrip.new()
	_lid_grip.name = "LidGrip"
	_lid_grip.grinder = self
	_lid_grip.mesh_root = _lid
	item.add_child(_lid_grip)
	_taker = GroundTaker.new()
	_taker.name = "GroundTaker"
	_taker.grinder = self
	_taker.mesh_root = _ground_mi
	item.add_child(_taker)
	_crunch = AudioStreamPlayer3D.new()
	_crunch.stream = _make_crunch()
	_crunch.unit_size = 1.2
	_crunch.volume_db = -4.0
	item.add_child(_crunch)
	_snap = AudioStreamPlayer3D.new()
	_snap.stream = CigarettePack._make_snap()
	_snap.unit_size = 1.5
	_snap.volume_db = -6.0
	item.add_child(_snap)
	mesh_root = base
	refresh_meshes()
	_apply_open(true)
	_update_contents()


func chamber_center() -> Vector3:
	return item.global_transform * Vector3(0, CH_FLOOR + 0.01, 0)


## Grinder tenu : l'autre main n'a accès qu'au couvercle et à l'herbe.
func accepts_hand(hand: Node3D) -> bool:
	if not is_grabbed() or hand in _grab_hands:
		return true
	var owner_hand = hand.get("owner_hand")
	return owner_hand != null and owner_hand in _grab_hands


## Une tête lâchée au-dessus de la chambre ouverte tombe dedans.
func try_receive(g: VRPickable) -> bool:
	if not (g is RollItem) or g.kind != "bud" or not open or buds >= MAX_BUDS or _lid == null:
		return false
	var p := item.global_transform.affine_inverse() * g.item.global_position
	if Vector2(p.x, p.z).length() > CH_R + 0.03 or p.y < -0.01 or p.y > 0.2:
		return false
	buds += 1
	g.item.queue_free()
	_snap.pitch_scale = 1.4
	_snap.play()
	_update_contents()
	return true


## A/X ou F : moud s'il y a des têtes (fermé), sinon ouvre / ferme.
func toggle() -> void:
	if not open and buds > 0:
		_auto_grind = 1.6
		return
	open = not open
	_apply_open(false)


func _apply_open(instant: bool) -> void:
	if _hinge == null:
		return
	var a := deg_to_rad(155.0) if open else 0.0
	if instant:
		_hinge.rotation.z = a
	else:
		create_tween().tween_property(_hinge, "rotation:z", a, 0.25)
		_snap.pitch_scale = 1.0 if open else 0.85
		_snap.play()
	refresh_state()


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (open and ground > 0.01) or _taker.is_grabbed()
	if _lid_grip:
		_lid_grip.enabled = (not open and buds > 0) or _lid_grip.is_grabbed()


## Le couvercle tourne de d radians (main qui le tourne, ou mouture automatique).
func turn_lid(d: float, hand: Node3D = null) -> void:
	if open or _lid == null:
		return
	_lid.rotation.y += d
	if buds <= 0:
		return
	if not _crunch.playing:
		_crunch.play()
	grind_progress += absf(d) / (TAU * 1.5)
	if hand and hand.has_method("pulse") and randf() < 0.3:
		hand.pulse(0.2, 0.02)
	if grind_progress >= 1.0:
		grind_progress = 0.0
		ground += float(buds)
		buds = 0
		grinds += 1
		stop_crunch()
		_update_contents()
		refresh_state()


func stop_crunch() -> void:
	if _crunch:
		_crunch.stop()


func _process(delta: float) -> void:
	if _auto_grind > 0.0:
		_auto_grind -= delta
		turn_lid(TAU * 1.5 / 1.4 * delta)
		if buds == 0 or _auto_grind <= 0.0:
			_auto_grind = 0.0
			stop_crunch()


func _update_contents() -> void:
	for i in _bud_nodes.size():
		_bud_nodes[i].visible = i < buds
	if _ground_mi:
		_ground_mi.visible = ground > 0.01
		var h := 0.002 + 0.012 * clampf(ground / 3.0, 0.0, 1.0)
		_ground_mesh.height = h
		_ground_mi.position = Vector3(0, CH_FLOOR + h * 0.5, 0)
	refresh_state()


## Sort une pincée d'herbe moulue dans la main ; renvoie son Grab.
func take_pinch_into(hand: Node3D) -> VRPickable:
	if ground <= 0.01:
		return null
	var q := minf(PINCH, ground)
	ground -= q
	if ground < 0.02:
		ground = 0.0
	var p := (load(PINCH_SCENE) as PackedScene).instantiate() as RigidBody3D
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(p)
	p.global_transform = Transform3D(item.global_basis, hand.global_position if hand.has_method("is_fingertip") else chamber_center())
	var g := p.get_node("Grab") as RollItem
	g.amount = q
	g.grab(hand)
	_update_contents()
	return g


## Craquement de la mouture (boucle) : petits clics secs aléatoires sur un frottement.
static func _make_crunch() -> AudioStreamWAV:
	var n := int(RATE * 0.8)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var click := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		if rng.randf() < 0.004:
			click = rng.randf_range(0.5, 1.0)
		click *= 0.93
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.2
		var v := lp * 0.25 + noise * click * 0.8
		var edge := clampf(minf(t, 0.8 - t) / 0.02, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v * edge, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
