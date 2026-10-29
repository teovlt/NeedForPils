class_name CigarettePack
extends VRPickable
## Paquet de cigarettes à couvercle rabattable (marque inventée « Route Libre »), avec
## un nombre aléatoire de cigarettes (3 à 20) tiré à chaque partie.
##
## - S'attrape et se range comme les autres objets (placé au hasard par CarStorage).
## - A/X (VR) ou F (bureau) en le visant ou en le tenant : ouvre / ferme le couvercle.
##   En VR, tenu d'une main, l'autre peut aussi le soulever par son bord avant.
## - Ouvert : main sur les cigarettes (VR) ou clic gauche en les visant (bureau) ->
##   une cigarette sort dans la main (Smokable : à allumer au briquet et à fumer).
##   La cigarette visée (la plus proche de la main) est la seule surlignée ; c'est elle
##   qui sort. En VR, grip ou gâchette (bout de l'index).
## - Tenu dans une main (VR) : l'autre main ne peut plus attraper le paquet lui-même,
##   seulement le couvercle et les cigarettes.
## - Les cigarettes visibles dans le paquet diminuent à mesure qu'on les prend.
## Repère : paquet debout, X largeur, Y hauteur (couvercle en haut), Z épaisseur
## (face avant vers +Z, charnière du couvercle à l'arrière).

const SIZE := Vector3(0.056, 0.088, 0.022)
const LID_H := 0.024                       # hauteur du couvercle
const CIG_SCENE := "res://props/items/cigarette_item.tscn"
const CIG_MODEL := "res://props/cigarette.glb"
const ROWS := [7, 6, 7]                    # 20 places, en quinconce

@export var count_range := Vector2i(3, 20)
@export var open := false

var cigarette_count := 0
var _cigs_root: Node3D
var _cig_nodes: Array[Node3D] = []
var _lid: Node3D
var _taker: Taker
var _snap: AudioStreamPlayer3D
var _pack_built := false
var _taken := 0   # cigarettes sorties (nom stable, le même chez les deux joueurs)


## Zone « les cigarettes dans le paquet » (active seulement paquet ouvert) : crée une
## vraie cigarette dans la main, qui suit ensuite les mouvements de la main.
class Taker:
	extends VRInteractable
	var pack
	var _held := {}

	var _target: Node3D           # cigarette visée (seule surlignée)

	func _ready() -> void:
		highlight_distance = 0.12
		grab_distance = 0.06          # large : on attrape facilement en approchant la main
		outline_width = 0.0012
		pick_bonus = 0.03
		grab_with_trigger = true
		super._ready()

	## Distance à la cigarette visible la plus proche (partie qui dépasse du paquet).
	func get_distance_to(global_point: Vector3) -> float:
		return pack.distance_to_cigarettes(global_point)

	func set_hand_distance(hand: Node3D, distance: float) -> void:
		if distance >= 0.0:
			_retarget(pack.nearest_cigarette(hand.global_position))
		super.set_hand_distance(hand, distance)

	## Le surlignage suit la cigarette visée.
	func _retarget(c: Node3D) -> void:
		if c == _target or c == null:
			return
		for m in _meshes:
			if is_instance_valid(m):
				m.material_overlay = null
		_target = c
		mesh_root = c
		refresh_meshes()

	func _on_grab_begin(hand: Node3D) -> void:
		var g = pack.take_cigarette_into(hand)
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
		pack.refresh_state()

	## F : sur la cigarette qu'on vient de sortir (l'allumer), sinon le couvercle.
	func toggle() -> void:
		for h in _held:
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		pack.toggle()


func _ready() -> void:
	super._ready()
	friction = 0.6
	cigarette_count = randi_range(count_range.x, count_range.y)
	_build.call_deferred()


## Boîte fixe (le modèle est construit en différé).
func get_local_aabb() -> AABB:
	return AABB(Vector3(-SIZE.x * 0.5, 0.0, -SIZE.z * 0.5), SIZE)


func _build() -> void:
	if _pack_built:
		return
	_pack_built = true
	var model := item.get_node_or_null("Model") as Node3D
	if model == null:
		model = Node3D.new()
		model.name = "Model"
		item.add_child(model)
	# coque du paquet (surlignée quand on vise / tient le paquet) ; les cigarettes sont
	# à part : seule celle qu'on vise est surlignée (CigaretteTaker)
	var shell := Node3D.new()
	shell.name = "Shell"
	model.add_child(shell)
	var white := _mat(Color(0.95, 0.94, 0.9))
	var red := _mat(Color(0.72, 0.1, 0.12))
	var gold := _mat(Color(0.85, 0.68, 0.3))
	var black := _mat(Color(0.08, 0.08, 0.08))
	var inner := _mat(Color(0.78, 0.74, 0.6))
	var foil := _mat(Color(0.82, 0.82, 0.8), 0.25, 0.8)
	var w := SIZE.x
	var d := SIZE.z
	var body_h := SIZE.y - LID_H
	# corps : parois fines (le dessus est ouvert), fond
	var t := 0.0012
	shell.add_child(_box(Vector3(w, body_h, t), Vector3(0, body_h * 0.5, d * 0.5 - t * 0.5), white))      # avant
	shell.add_child(_box(Vector3(w, body_h, t), Vector3(0, body_h * 0.5, -d * 0.5 + t * 0.5), white))     # arrière
	for sx in [-1.0, 1.0]:
		shell.add_child(_box(Vector3(t, body_h, d - 2 * t), Vector3(sx * (w * 0.5 - t * 0.5), body_h * 0.5, 0), white))
	shell.add_child(_box(Vector3(w, t, d), Vector3(0, t * 0.5, 0), white))
	# languette intérieure (collerette en carton) qui dépasse du corps à l'avant
	shell.add_child(_box(Vector3(w - 0.004, 0.012, 0.0008), Vector3(0, body_h + 0.004, d * 0.5 - 0.0025), inner))
	# décor de la face avant : bandeau rouge en chevron, nom de marque, avertissement
	shell.add_child(_box(Vector3(w + 0.0002, 0.016, 0.0004), Vector3(0, body_h - 0.012, d * 0.5 + 0.0002), red))
	shell.add_child(_box(Vector3(w + 0.0002, 0.0015, 0.0004), Vector3(0, body_h - 0.0205, d * 0.5 + 0.0003), gold))
	shell.add_child(_label("ROUTE LIBRE", Vector3(0, body_h - 0.012, d * 0.5 + 0.0006), 0.00011, Color(1, 0.95, 0.85), 0.0))
	shell.add_child(_box(Vector3(w - 0.004, 0.02, 0.0004), Vector3(0, 0.015, d * 0.5 + 0.0002), black))
	shell.add_child(_label("FUMER TUE", Vector3(0, 0.015, d * 0.5 + 0.0006), 0.00014, Color.WHITE, 0.0))
	shell.add_child(_box(Vector3(w - 0.004, 0.02, 0.0004), Vector3(0, 0.015, -d * 0.5 - 0.0002), black))
	shell.add_child(_label("FUMER TUE", Vector3(0, 0.015, -d * 0.5 - 0.0006), 0.00014, Color.WHITE, PI))
	# couvercle rabattable (charnière en haut à l'arrière du corps)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, body_h, -d * 0.5)
	shell.add_child(_lid)
	_lid.add_child(_box(Vector3(w, LID_H, t), Vector3(0, LID_H * 0.5, d - t * 0.5), white))
	_lid.add_child(_box(Vector3(w, LID_H, t), Vector3(0, LID_H * 0.5, t * 0.5), white))
	for sx in [-1.0, 1.0]:
		_lid.add_child(_box(Vector3(t, LID_H, d - 2 * t), Vector3(sx * (w * 0.5 - t * 0.5), LID_H * 0.5, d * 0.5), white))
	_lid.add_child(_box(Vector3(w, t, d), Vector3(0, LID_H - t * 0.5, d * 0.5), white))
	_lid.add_child(_box(Vector3(w + 0.0002, 0.009, 0.0004), Vector3(0, LID_H * 0.45, d + 0.0002), red))
	_lid.add_child(_box(Vector3(0.012, 0.0004, 0.012), Vector3(0, LID_H + 0.0002, d * 0.5), gold))   # écusson
	# papier alu au-dessus des cigarettes
	shell.add_child(_box(Vector3(w - 0.006, 0.0006, 0.004), Vector3(0, body_h + 0.016, -d * 0.5 + 0.004), foil))
	# cigarettes debout, filtre en haut
	_cigs_root = Node3D.new()
	_cigs_root.name = "Cigarettes"
	model.add_child(_cigs_root)
	var cig := load(CIG_MODEL) as PackedScene
	var slots: Array[Vector3] = []
	for r in ROWS.size():
		var n: int = ROWS[r]
		for i in n:
			var x := (i - (n - 1) * 0.5) * 0.0078
			var z := (r - 1.0) * 0.0064
			slots.append(Vector3(x, 0.001, z))
	# la place la plus en avant d'abord vidée : on prend dans la rangée de devant
	for i in slots.size():
		var holder := Node3D.new()
		holder.position = slots[i]
		# le modèle regarde vers +X, filtre en -X : on le dresse, filtre vers le haut
		holder.basis = Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
		var c := cig.instantiate() as Node3D
		c.position = Vector3(-0.042, 0, 0)    # bout (x = +0,042) posé au fond
		holder.add_child(c)
		_cigs_root.add_child(holder)
		_cig_nodes.append(holder)
	var to_hide := slots.size() - cigarette_count
	var order := range(slots.size())
	order.shuffle()
	for k in to_hide:
		_cig_nodes[order[k]].visible = false
	_taker = Taker.new()
	_taker.name = "CigaretteTaker"
	_taker.pack = self
	_taker.mesh_root = _cigs_root
	item.add_child(_taker)
	_snap = AudioStreamPlayer3D.new()
	_snap.stream = _make_snap()
	_snap.unit_size = 1.5
	_snap.volume_db = -6.0
	item.add_child(_snap)
	for mi in model.find_children("*", "Label3D", true, false):
		mi.set_meta("_vr_outline", true)
	# VR : l'autre main tire le couvercle par son bord avant -> ouvre / ferme
	var lh := VRGestureHandle.new()
	lh.name = "LidHandle"
	lh.owner_grab = self
	lh.mesh_root = _lid
	lh.segment = VRGestureHandle.part_segment(_lid, "bord")
	lh.action = toggle
	item.add_child(lh)
	mesh_root = shell
	refresh_meshes()
	_apply_open(true)
	print("Paquet de cigarettes : %d cigarettes" % cigarette_count)


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	return mi


func _label(text: String, pos: Vector3, px: float, c: Color, yaw: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	return l


func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Visée souris : paquet ouvert, viser le dessus (les cigarettes) désigne les cigarettes.
func ray_hit_distance(origin: Vector3, dir: Vector3, max_t: float, margin: float) -> float:
	var t := super.ray_hit_distance(origin, dir, max_t, margin)
	if t == INF or not open or cigarettes_left() == 0 or item == null:
		return t
	var inv := item.global_transform.affine_inverse()
	var o := inv * origin
	var dl := inv.basis * dir
	if absf(dl.y) < 1e-4:
		return t
	var k := (SIZE.y - LID_H + 0.004 - o.y) / dl.y
	if k < 0.0:
		return t
	var hit := o + dl * k
	if absf(hit.x) < SIZE.x * 0.48 and absf(hit.z) < SIZE.z * 0.5:
		return INF
	return t


func ray_hit_precise(origin: Vector3, dir: Vector3, max_t: float) -> float:
	if ray_hit_distance(origin, dir, max_t, 0.0) == INF and open:
		return INF
	return super.ray_hit_precise(origin, dir, max_t)


## Paquet tenu : seule la main qui le tient y a accès ; l'autre ne prend que les
## cigarettes (zone CigaretteTaker).
func accepts_hand(hand: Node3D) -> bool:
	if not is_grabbed():
		return true
	if hand in _grab_hands:
		return true
	var owner_hand = hand.get("owner_hand")   # bout de l'index de la main qui tient
	return owner_hand != null and owner_hand in _grab_hands


## Haut d'une cigarette (bout du filtre) et point d'entrée dans le paquet (monde).
func _cig_segment(c: Node3D) -> Array:
	# le support dresse le modèle : son X local pointe vers le bas, filtre en haut
	return [c.global_transform * Vector3(-0.05, 0, 0), c.global_transform * Vector3(-0.084, 0, 0)]


func distance_to_cigarettes(global_point: Vector3) -> float:
	var best := INF
	for c in _cig_nodes:
		if c.visible:
			var sg := _cig_segment(c)
			var q := Geometry3D.get_closest_point_to_segment(global_point, sg[0], sg[1])
			best = minf(best, q.distance_to(global_point) - 0.004)
	return maxf(best, 0.0)


func nearest_cigarette(global_point: Vector3) -> Node3D:
	var node: Node3D = null
	var best := INF
	for c in _cig_nodes:
		if c.visible:
			var sg := _cig_segment(c)
			var d := Geometry3D.get_closest_point_to_segment(global_point, sg[0], sg[1]).distance_to(global_point)
			if d < best:
				best = d
				node = c
	return node


func cigarettes_left() -> int:
	var n := 0
	for c in _cig_nodes:
		if c.visible:
			n += 1
	return n


## A/X en VR : comme F.
func vr_button() -> void:
	toggle()


func toggle() -> void:
	open = not open
	_apply_open(false)


func _apply_open(instant: bool) -> void:
	if _lid:
		var a := deg_to_rad(-115.0 if open else 0.0)
		if instant:
			_lid.rotation.x = a
		else:
			create_tween().tween_property(_lid, "rotation:x", a, 0.18)
			if _snap:
				_snap.pitch_scale = 1.1 if open else 0.85
				_snap.play()
	refresh_state()


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (open and cigarettes_left() > 0) or _taker.is_grabbed()


## Sort une cigarette du paquet dans la main ; renvoie son Grab.
func take_cigarette_into(hand: Node3D) -> VRPickable:
	# la cigarette surlignée (visée) en priorité, sinon la plus proche de la main
	var node := nearest_cigarette(hand.global_position)
	var tg: Node3D = _taker._target if _taker else null
	if tg and tg.visible and distance_to_cigarettes(hand.global_position) > -1.0:
		var sg := _cig_segment(tg)
		if Geometry3D.get_closest_point_to_segment(hand.global_position, sg[0], sg[1]).distance_to(hand.global_position) < 0.1:
			node = tg
	if node == null:
		return null
	node.visible = false
	var cig := (load(CIG_SCENE) as PackedScene).instantiate() as RigidBody3D
	_taken += 1
	cig.name = "%s_Cig%d" % [item.name, _taken]
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(cig)
	# position de la cigarette qu'on vient de sortir (un peu plus haut, déjà à moitié dehors)
	cig.global_transform = (node.get_child(0) as Node3D).global_transform.translated(item.global_basis.y * 0.03)
	var g := cig.get_node("Grab") as VRPickable
	g.grab(hand)
	refresh_state()
	return g


## « Clac » du couvercle.
static func _make_snap() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.08)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in n:
		var tt := float(i) / rate
		var v := (rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 900.0 * tt) * 0.4) * exp(-tt * 90.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
