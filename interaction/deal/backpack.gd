class_name Backpack
extends Node3D
## Sac à dos posé sur la banquette arrière, à côté de la glacière
## (props/backpack/backpack.glb : Body, Flap), plein de sachets de pilules smiley prêts
## à la livraison (5 à 10 DealerBag).
##
## - Rabat : se soulève à la main (VR : le saisir et le basculer ; souris : tirer) ou F
##   en le visant (VRHingeInteractable, couture à l'arrière).
## - Ouvert : la main prend le sachet le plus proche (surligné) ; clic gauche à la souris.
##   Le sachet s'ouvre et se vide comme la pochette de pilules.
## - Un sachet lâché au-dessus du sac ouvert y retourne, avec ce qu'il lui reste
##   (entamé ou vide, il ne se remplit pas : on voit moins de smileys dedans).
## - Le sac lui-même se prend par sa poignée (boucle en haut du dos) ou ses flancs
##   (VR : grip ; souris : clic gauche) : il suit la main, on peut l'amener devant soi
##   et y piocher les sachets de l'autre main. Lâché, il retourne se caler à sa place sur
##   la banquette (pas de physique : il ne s'envole pas).
## Les sachets sortis ont un nom stable (le même chez les deux joueurs).

const MODEL := "res://props/backpack/backpack.glb"
const BAG_SCENE := "res://props/items/dealer_bag_item.tscn"
const SMILEY_MODEL := "res://props/pill_smiley.glb"
const W := 0.31
const D := 0.17
const H := 0.40
const FILL_TOP := 0.24          # affaires au fond : les sachets sont posés dessus
const SLOTS := 10
## Poignée de portage (backpack_build.py), repère du sac.
const HANDLE := Vector3(0, H - 0.012, -D / 2 - 0.022)
## Durée (s) du retour à sa place une fois lâché.
const RETURN_TIME := 0.35

## Nombre de sachets au départ (tiré à chaque partie).
@export var bag_range := Vector2i(5, 10)
## Pilules par sachet plein (tiré pour chaque sachet).
@export var smiley_range := Vector2i(8, 12)

var flap: VRHingeInteractable
var carry: Carry
var _slots: Array[Node3D] = []
var _taker: SachetTaker
var _taken := 0
var _home: Transform3D           # place sur la banquette (repère de la voiture)
var _return_tween: Tween


## Prise du sac lui-même (poignée, flancs) : il suit la main qui le tient.
class Carry:
	extends VRInteractable
	var pack
	var _active: Node3D
	var _offset := Transform3D.IDENTITY

	func _ready() -> void:
		highlight_distance = 0.12
		grab_distance = 0.07
		outline_width = 0.004
		super._ready()

	## Poignée en priorité ; ailleurs, distance à la surface du sac (main plongée dedans
	## = loin : c'est pour les sachets ou le rabat).
	func get_distance_to(global_point: Vector3) -> float:
		var l: Vector3 = pack.global_transform.affine_inverse() * global_point
		var handle := l.distance_to(HANDLE) - 0.02
		var half := Vector3(W * 0.5, H * 0.5, D * 0.5)
		var q := (l - Vector3(0, H * 0.5, 0)).abs() - half
		var outside := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
		var surface := outside if outside > 0.0 else -maxf(q.x, maxf(q.y, q.z))
		return maxf(minf(handle, surface + 0.02), 0.0)

	func _on_grab_begin(hand: Node3D) -> void:
		_take(hand)

	func _on_grab_update(hand: Node3D) -> void:
		if hand == _active:
			pack.global_transform = _hand_xf(hand) * _offset

	func _on_grab_end(hand: Node3D) -> void:
		if hand != _active:
			return
		if is_grabbed():
			_take(_grab_hands[-1])   # l'autre main reprend le sac
			return
		_active = null
		pack.put_back()

	func _take(hand: Node3D) -> void:
		_active = hand
		pack.lift()
		_offset = _hand_xf(hand).affine_inverse() * pack.global_transform

	func _hand_xf(hand: Node3D) -> Transform3D:
		if hand.has_method("visual_transform"):
			return hand.visual_transform()
		return hand.global_transform


class SachetTaker:
	extends VRInteractable
	var pack
	var _held := {}
	var _target: Node3D

	func _ready() -> void:
		highlight_distance = 0.14
		grab_distance = 0.07
		outline_width = 0.0015
		pick_bonus = 0.04
		grab_with_trigger = true
		super._ready()

	func get_distance_to(global_point: Vector3) -> float:
		return pack.distance_to_bags(global_point)

	func set_hand_distance(hand: Node3D, distance: float) -> void:
		if distance >= 0.0:
			var c: Node3D = pack.nearest_bag(hand.global_position)
			if c and c != _target:
				for m in _meshes:
					if is_instance_valid(m):
						m.material_overlay = null
				_target = c
				mesh_root = c
				refresh_meshes()
		super.set_hand_distance(hand, distance)

	func _on_grab_begin(hand: Node3D) -> void:
		var g = pack.take_bag_into(hand)
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

	func toggle() -> void:
		for h in _held:
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		pack.flap.toggle()


func _ready() -> void:
	add_to_group(VRPickable.RECEIVERS)
	var parts := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(parts)
	var body := parts.find_child("Body", true, false) as Node3D
	var flap_mesh := parts.find_child("Flap", true, false) as Node3D
	body.reparent(self, false)
	flap = VRHingeInteractable.new()
	flap.name = "Flap"
	flap.hinge_axis = Vector3(1, 0, 0)
	flap.min_angle_deg = -125.0
	flap.max_angle_deg = 0.0
	flap.snap_closed_deg = 8.0
	flap.highlight_distance = 0.12
	flap.grab_distance = 0.07
	flap.outline_width = 0.004
	flap.position = Vector3(0, H, -D / 2)
	add_child(flap)
	var fxf := flap_mesh.transform
	flap_mesh.reparent(flap, false)
	flap_mesh.transform = Transform3D(fxf.basis, Vector3.ZERO)
	flap.opened.connect(refresh_state)
	flap.closed.connect(refresh_state)
	parts.queue_free()
	# affaires au fond (sweat roulé), les sachets debout par-dessus
	var stuff := MeshInstance3D.new()
	stuff.name = "Stuff"
	var sm := BoxMesh.new()
	sm.size = Vector3(W * 0.78, FILL_TOP - 0.02, D * 0.72)
	stuff.mesh = sm
	var stm := StandardMaterial3D.new()
	stm.albedo_color = Color(0.18, 0.22, 0.32)
	stm.roughness = 1.0
	stuff.material_override = stm
	stuff.position = Vector3(0, 0.02 + (FILL_TOP - 0.02) * 0.5, 0)
	add_child(stuff)
	var root := Node3D.new()
	root.name = "Bags"
	root.set_meta("no_held_collision", true)   # la main plonge dans le sac
	add_child(root)
	var n := randi_range(bag_range.x, bag_range.y)
	for i in SLOTS:
		var b := _sachet_visual()
		b.position = Vector3(-0.1 + i * 0.0222, FILL_TOP, randf_range(-0.012, 0.012))
		b.rotation = Vector3(0, PI * 0.5 + randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
		b.visible = i < n
		var lot := randi_range(smiley_range.x, smiley_range.y)
		b.set_meta("pills", lot)   # pilules dans ce sachet
		b.set_meta("lot", lot)     # pilules du lot complet
		root.add_child(b)
		_slots.append(b)
	_taker = SachetTaker.new()
	_taker.name = "SachetTaker"
	_taker.pack = self
	_taker.mesh_root = root
	add_child(_taker)
	_home = transform
	carry = Carry.new()
	carry.name = "Carry"
	carry.pack = self
	carry.mesh_root = body
	add_child(carry)
	refresh_state()


## Sac pris en main : il quitte la banquette (suit la main dans le monde) ; ses
## collisions « objet tenu » sont coupées pour ne pas repousser la main qui le tient.
func lift() -> void:
	if _return_tween:
		_return_tween.kill()
		_return_tween = null
	if not top_level:
		top_level = true
	_set_held_collision(false)


## Sac lâché : il retourne en douceur à sa place sur la banquette.
func put_back() -> void:
	var from := (get_parent() as Node3D).global_transform.affine_inverse() * global_transform
	top_level = false
	transform = from
	_return_tween = create_tween()
	_return_tween.tween_property(self, "transform", _home, RETURN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_return_tween.tween_callback(_set_held_collision.bind(true))


func is_carried() -> bool:
	return carry != null and carry.is_grabbed()


func _set_held_collision(on: bool) -> void:
	for b in find_children("HeldCollision", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = CarStorage.HELD_LAYER if on else 0


## Sachet debout dans le sac (simple maquette : film, zip, quelques smileys).
func _sachet_visual() -> Node3D:
	var n := Node3D.new()
	var film := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.05, 0.07, 0.006)
	film.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	film.material_override = mat
	film.position = Vector3(0, 0.035, 0)
	n.add_child(film)
	var zip := MeshInstance3D.new()
	var zm := BoxMesh.new()
	zm.size = Vector3(0.05, 0.006, 0.007)
	zip.mesh = zm
	var zmat := StandardMaterial3D.new()
	zmat.albedo_color = Color(0.85, 0.15, 0.15)
	zip.material_override = zmat
	zip.position = Vector3(0, 0.067, 0)
	n.add_child(zip)
	var pill := load(SMILEY_MODEL) as PackedScene
	for k in 5:
		var p := pill.instantiate() as Node3D
		p.scale = Vector3.ONE * 0.8
		p.position = Vector3(-0.015 + (k % 3) * 0.015, 0.012 + (k / 3) * 0.012, 0)
		p.rotation = Vector3(PI * 0.5, 0, 0)
		p.set_meta("smiley", true)
		n.add_child(p)
	return n


## Smileys visibles dans un sachet du sac, selon ce qu'il lui reste.
func _show_fill(b: Node3D) -> void:
	var pills: int = b.get_meta("pills", 0)
	var lot: int = maxi(b.get_meta("lot", 1), 1)
	var shown := 0 if pills <= 0 else clampi(ceili(5.0 * pills / lot), 1, 5)
	var k := 0
	for c in b.get_children():
		if c.has_meta("smiley"):
			(c as Node3D).visible = k < shown
			k += 1


func bags_left() -> int:
	var n := 0
	for b in _slots:
		if b.visible:
			n += 1
	return n


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (flap.is_open() and bags_left() > 0) or _taker.is_grabbed()


func distance_to_bags(p: Vector3) -> float:
	var best := INF
	for b in _slots:
		if b.visible:
			var a := b.global_transform * Vector3(0, 0.01, 0)
			var c := b.global_transform * Vector3(0, 0.07, 0)
			best = minf(best, Geometry3D.get_closest_point_to_segment(p, a, c).distance_to(p) - 0.01)
	return maxf(best, 0.0)


func nearest_bag(p: Vector3) -> Node3D:
	var node: Node3D = null
	var best := INF
	for b in _slots:
		if b.visible:
			var d := (b.global_transform * Vector3(0, 0.05, 0)).distance_to(p)
			if d < best:
				best = d
				node = b
	return node


## Sort un sachet dans la main ; renvoie son Grab.
func take_bag_into(hand: Node3D) -> VRPickable:
	var node := nearest_bag(hand.global_position)
	var tg: Node3D = _taker._target if _taker else null
	if tg and tg.visible and (tg.global_transform * Vector3(0, 0.05, 0)).distance_to(hand.global_position) < 0.15:
		node = tg
	if node == null:
		return null
	node.visible = false
	var bag := (load(BAG_SCENE) as PackedScene).instantiate() as RigidBody3D
	var dg := bag.get_node("Grab") as DealerBag
	dg.preset_count = node.get_meta("pills", -1)   # ce qu'il reste dans ce sachet
	dg.lot_size = node.get_meta("lot", 0)
	_taken += 1
	bag.name = "%s_Bag_%d" % [name, _taken]   # nom stable, le même chez les deux joueurs
	var storage := get_tree().get_first_node_in_group(CarStorage.GROUP) as Node
	(storage if storage else get_parent()).add_child(bag)
	# à plat dans la main, à l'endroit où était le sachet
	bag.global_transform = Transform3D(global_basis, node.global_transform * Vector3(0, 0.05, 0))
	if hand.has_method("is_fingertip"):
		bag.global_position = hand.global_position
	var g := bag.get_node("Grab") as VRPickable
	g.grab(hand)
	refresh_state()
	return g


## Sachet lâché au-dessus du sac ouvert : il y retourne.
func try_receive(g: VRPickable) -> bool:
	if not (g is DealerBag) or not flap.is_open():
		return false
	var l := global_transform.affine_inverse() * g.item.global_position
	if absf(l.x) > W * 0.5 or absf(l.z) > D * 0.6 or l.y < FILL_TOP - 0.02 or l.y > H + 0.25:
		return false
	for b in _slots:
		if not b.visible:
			b.visible = true
			b.set_meta("pills", (g as DealerBag).pills_left())   # entamé : il le reste
			b.set_meta("lot", (g as DealerBag).lot_size)
			_show_fill(b)
			g.item.queue_free()
			refresh_state()
			return true
	return false
