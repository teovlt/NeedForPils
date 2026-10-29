class_name Cooler
extends Node3D
## Glacière posée sur la banquette arrière (props/cooler/cooler.glb : Body, Lid), avec
## des canettes de bière (BeerCan) dans la glace.
##
## - Couvercle : se soulève à la main (VR : le saisir et le basculer ; souris : tirer) ou
##   F en le visant (VRHingeInteractable, charnière à l'arrière).
## - Ouverte : la main prend la canette la plus proche (surlignée) ; clic gauche à la
##   souris.
## - Une canette encore fermée lâchée au-dessus de la glacière ouverte y retourne.
## Les canettes sorties ont un nom stable (le même chez les deux joueurs).

const MODEL := "res://props/cooler/cooler.glb"
const CAN_MODEL := "res://props/cooler/beer_can.glb"
const CAN_SCENE := "res://props/items/beer_can_item.tscn"
const W := 0.40
const D := 0.27
const BODY_H := 0.24
const T := 0.022
const SLOTS := [Vector3(-0.1, 0, -0.05), Vector3(0.0, 0, -0.05), Vector3(0.1, 0, -0.05),
		Vector3(-0.1, 0, 0.05), Vector3(0.0, 0, 0.05), Vector3(0.1, 0, 0.05)]

## Nombre de canettes au départ (tiré à chaque partie).
@export var can_range := Vector2i(4, 6)

var lid: VRHingeInteractable
var _cans_root: Node3D
var _slots: Array[Node3D] = []
var _taker: CanTaker
var _taken := 0


class CanTaker:
	extends VRInteractable
	var cooler
	var _held := {}
	var _target: Node3D

	func _ready() -> void:
		highlight_distance = 0.16
		grab_distance = 0.08
		outline_width = 0.002
		pick_bonus = 0.04
		super._ready()

	func get_distance_to(global_point: Vector3) -> float:
		return cooler.distance_to_cans(global_point)

	func set_hand_distance(hand: Node3D, distance: float) -> void:
		if distance >= 0.0:
			var c: Node3D = cooler.nearest_can(hand.global_position)
			if c and c != _target:
				for m in _meshes:
					if is_instance_valid(m):
						m.material_overlay = null
				_target = c
				mesh_root = c
				refresh_meshes()
		super.set_hand_distance(hand, distance)

	func _on_grab_begin(hand: Node3D) -> void:
		var g = cooler.take_can_into(hand)
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
		cooler.refresh_state()

	func toggle() -> void:
		for h in _held:
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		cooler.lid.toggle()


func _ready() -> void:
	add_to_group(VRPickable.RECEIVERS)
	var parts := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(parts)
	var body := parts.find_child("Body", true, false) as Node3D
	var lid_mesh := parts.find_child("Lid", true, false) as Node3D
	body.reparent(self, false)
	# couvercle sur charnière (axe X, à l'arrière), qui bascule vers l'arrière
	lid = VRHingeInteractable.new()
	lid.name = "Lid"
	lid.hinge_axis = Vector3(1, 0, 0)
	lid.min_angle_deg = -105.0
	lid.max_angle_deg = 0.0
	lid.snap_closed_deg = 6.0
	lid.highlight_distance = 0.12
	lid.grab_distance = 0.07
	lid.outline_width = 0.004
	lid.position = Vector3(0, BODY_H, -D / 2)
	add_child(lid)
	var lxf := lid_mesh.transform
	lid_mesh.reparent(lid, false)
	lid_mesh.transform = Transform3D(lxf.basis, Vector3.ZERO)
	lid.opened.connect(refresh_state)
	lid.closed.connect(refresh_state)
	parts.queue_free()
	# canettes debout dans la glace (sans collision « objet tenu » : la main y plonge)
	_cans_root = Node3D.new()
	_cans_root.name = "Cans"
	_cans_root.set_meta("no_held_collision", true)
	add_child(_cans_root)
	var cs := load(CAN_MODEL) as PackedScene
	var n := randi_range(can_range.x, can_range.y)
	var order := range(SLOTS.size())
	order.shuffle()
	for i in SLOTS.size():
		var c := cs.instantiate() as Node3D
		c.position = SLOTS[i] + Vector3(0, T + 0.004, 0)
		c.rotation.y = randf() * TAU
		c.visible = order.find(i) < n
		_cans_root.add_child(c)
		_slots.append(c)
	_taker = CanTaker.new()
	_taker.name = "CanTaker"
	_taker.cooler = self
	_taker.mesh_root = _cans_root
	add_child(_taker)
	refresh_state()


func cans_left() -> int:
	var n := 0
	for c in _slots:
		if c.visible:
			n += 1
	return n


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (lid.is_open() and cans_left() > 0) or _taker.is_grabbed()


func distance_to_cans(p: Vector3) -> float:
	var best := INF
	for c in _slots:
		if c.visible:
			var a := c.global_transform * Vector3(0, 0.03, 0)
			var b := c.global_transform * Vector3(0, 0.11, 0)
			best = minf(best, Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p) - 0.033)
	return maxf(best, 0.0)


func nearest_can(p: Vector3) -> Node3D:
	var node: Node3D = null
	var best := INF
	for c in _slots:
		if c.visible:
			var d := (c.global_transform * Vector3(0, 0.08, 0)).distance_to(p)
			if d < best:
				best = d
				node = c
	return node


## Sort une canette dans la main ; renvoie son Grab.
func take_can_into(hand: Node3D) -> VRPickable:
	var node := nearest_can(hand.global_position)
	var tg: Node3D = _taker._target if _taker else null
	if tg and tg.visible and (tg.global_transform * Vector3(0, 0.08, 0)).distance_to(hand.global_position) < 0.15:
		node = tg
	if node == null:
		return null
	node.visible = false
	var can := (load(CAN_SCENE) as PackedScene).instantiate() as RigidBody3D
	_taken += 1
	can.name = "%s_Can_%d" % [name, _taken]   # nom stable, le même chez les deux joueurs
	var storage := get_tree().get_first_node_in_group(CarStorage.GROUP) as Node
	(storage if storage else get_parent()).add_child(can)
	can.global_transform = node.global_transform
	var g := can.get_node("Grab") as VRPickable
	g.grab(hand)
	refresh_state()
	return g


## Canette fermée lâchée au-dessus de la glacière ouverte : elle retourne dans la glace.
func try_receive(g: VRPickable) -> bool:
	if not (g is BeerCan) or g.opened or g.fill < 0.99 or not lid.is_open():
		return false
	var l := global_transform.affine_inverse() * g.item.global_position
	if absf(l.x) > W * 0.5 or absf(l.z) > D * 0.5 or l.y < 0.0 or l.y > BODY_H + 0.25:
		return false
	for c in _slots:
		if not c.visible:
			c.visible = true
			g.item.queue_free()
			refresh_state()
			return true
	return false
