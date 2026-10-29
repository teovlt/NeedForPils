class_name RollDispenser
extends VRPickable
## Carnet de feuilles à rouler (props/rolling/papers.glb : Body, Stack, Flap) ou boîte de
## filtres (props/rolling/filter_box.glb : Body, Lid ; filtres props/rolling/filter.glb).
##
## - A/X (VR) ou F (bureau) : ouvre / ferme le rabat ; en VR, tenu d'une main, l'autre
##   peut aussi le tirer par son bord.
## - Ouvert : l'autre main (grip, ou bout de l'index à la gâchette) prend une feuille /
##   un filtre (le plus proche de la main, surligné) ; clic gauche à la souris.
## - Tenu dans une main : l'autre main n'a accès qu'au contenu.
## - Une feuille encore vierge (ni herbe, ni tabac, ni filtre) ou un filtre lâché
##   au-dessus du carnet / de la boîte ouverts y retourne.

const SHEET_SCENE := "res://props/items/sheet_item.tscn"
const FILTER_SCENE := "res://props/items/filter_item.tscn"
const FILTER_MODEL := "res://props/rolling/filter.glb"

@export_enum("papers", "filters") var style := "papers"
@export var count_range := Vector2i(20, 32)
@export var open := false

var count := 0
var _max := 1
var _flap: Node3D
var _stack: Node3D
var _units: Array[Node3D] = []
var _units_root: Node3D
var _taker: UnitTaker
var _snap: AudioStreamPlayer3D
var _built_d := false
var _taken := 0   # feuilles / filtres sortis (nom stable, le même chez les deux joueurs)


class UnitTaker:
	extends VRInteractable
	var disp
	var _held := {}
	var _target: Node3D

	func _ready() -> void:
		highlight_distance = 0.1
		grab_distance = 0.05
		outline_width = 0.0012
		pick_bonus = 0.035
		grab_with_trigger = true
		super._ready()

	func get_distance_to(global_point: Vector3) -> float:
		return disp.distance_to_units(global_point)

	func set_hand_distance(hand: Node3D, distance: float) -> void:
		if distance >= 0.0 and disp.style == "filters":
			var c: Node3D = disp.nearest_unit(hand.global_position)
			if c and c != _target:
				for m in _meshes:
					if is_instance_valid(m):
						m.material_overlay = null
				_target = c
				mesh_root = c
				refresh_meshes()
		super.set_hand_distance(hand, distance)

	func _on_grab_begin(hand: Node3D) -> void:
		var g = disp.take_into(hand)
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
		disp.refresh_state()

	func toggle() -> void:
		for h in _held:
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		disp.toggle()


func _ready() -> void:
	super._ready()
	add_to_group(RECEIVERS)
	rest_up_axis = 1
	friction = 0.6
	count = randi_range(count_range.x, count_range.y)
	_build.call_deferred()


func _build() -> void:
	if _built_d:
		return
	_built_d = true
	var model := item.get_node_or_null("Model")
	if model == null:
		return
	var body := model.find_child("Body", true, false) as Node3D
	var shell := Node3D.new()
	shell.name = "Shell"
	body.get_parent().add_child(shell)
	if style == "papers":
		_max = 32
		_flap = model.find_child("Flap", true, false) as Node3D
		_stack = model.find_child("Stack", true, false) as Node3D
		_units_root = _stack
		_reparent_keep(body, shell)
		_reparent_keep(_flap, shell)
		var l := _label("SLIM LIBRE", Color(0.98, 0.92, 0.75), 0.00012)
		l.position = Vector3(0, 0.0012, 0.019)
		l.rotation = Vector3(-PI * 0.5, 0, 0)
		_flap.add_child(l)
		var l2 := _label("feuilles à rouler", Color(0.95, 0.88, 0.7), 0.00006)
		l2.position = Vector3(0, 0.0012, 0.03)
		l2.rotation = Vector3(-PI * 0.5, 0, 0)
		_flap.add_child(l2)
	else:
		_max = 24
		_flap = model.find_child("Lid", true, false) as Node3D
		_reparent_keep(body, shell)
		_reparent_keep(_flap, shell)
		var l := _label("FILTRES", Color(0.95, 0.95, 0.92), 0.00012)
		l.position = Vector3(0, 0.0012, 0.015)
		l.rotation = Vector3(-PI * 0.5, 0, 0)
		_flap.add_child(l)
		_units_root = Node3D.new()
		_units_root.name = "Filters"
		body.get_parent().add_child(_units_root)
		var fs := load(FILTER_MODEL) as PackedScene
		for r in 4:
			for c in 6:
				var f := fs.instantiate() as Node3D
				f.position = Vector3(-0.0195 + c * 0.0078, 0.001, -0.0105 + r * 0.007)
				_units_root.add_child(f)
				_units.append(f)
		var order := range(_units.size())
		order.shuffle()
		for k in _units.size() - mini(count, _units.size()):
			_units[order[k]].visible = false
	for lb in model.find_children("*", "Label3D", true, false):
		lb.set_meta("_vr_outline", true)
	_taker = UnitTaker.new()
	_taker.name = "UnitTaker"
	_taker.disp = self
	_taker.mesh_root = _units_root
	item.add_child(_taker)
	_snap = AudioStreamPlayer3D.new()
	_snap.stream = CigarettePack._make_snap()
	_snap.unit_size = 1.5
	_snap.volume_db = -8.0
	item.add_child(_snap)
	# VR : l'autre main tire le rabat par son bord -> ouvre / ferme
	var fh := VRGestureHandle.new()
	fh.name = "FlapHandle"
	fh.owner_grab = self
	fh.mesh_root = _flap
	fh.segment = VRGestureHandle.part_segment(_flap, "bord")
	fh.action = toggle
	item.add_child(fh)
	mesh_root = shell
	refresh_meshes()
	_apply_open(true)
	_update_units()


func _reparent_keep(n: Node3D, p: Node3D) -> void:
	var xf := n.global_transform
	n.get_parent().remove_child(n)
	p.add_child(n)
	n.global_transform = xf


func _label(text: String, c: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.double_sided = false
	return l


func left() -> int:
	if style == "papers":
		return count
	var n := 0
	for u in _units:
		if u.visible:
			n += 1
	return n


func accepts_hand(hand: Node3D) -> bool:
	if not is_grabbed() or hand in _grab_hands:
		return true
	var owner_hand = hand.get("owner_hand")
	return owner_hand != null and owner_hand in _grab_hands


func distance_to_units(p: Vector3) -> float:
	if style == "papers":
		var top := item.global_transform * Vector3(0, 0.001 + 0.0045 * _stack.scale.y, 0.0005)
		var l := item.global_transform.affine_inverse() * p
		var q := Vector3(clampf(l.x, -0.035, 0.035), 0.001 + 0.0045 * _stack.scale.y, clampf(l.z, -0.018, 0.018))
		return (item.global_transform * q).distance_to(p) if top else INF
	var best := INF
	for u in _units:
		if u.visible:
			best = minf(best, (u.global_transform * Vector3(0, 0.014, 0)).distance_to(p) - 0.003)
	return maxf(best, 0.0)


func nearest_unit(p: Vector3) -> Node3D:
	var node: Node3D = null
	var best := INF
	for u in _units:
		if u.visible:
			var d := (u.global_transform * Vector3(0, 0.014, 0)).distance_to(p)
			if d < best:
				best = d
				node = u
	return node


## Visée souris : ouvert, viser le dessus désigne le contenu (pas le carnet / la boîte).
func ray_hit_distance(origin: Vector3, dir: Vector3, max_t: float, margin: float) -> float:
	var t := super.ray_hit_distance(origin, dir, max_t, margin)
	if t == INF or not open or left() == 0 or item == null:
		return t
	var inv := item.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.y) < 1e-4:
		return t
	var top := 0.006 if style == "papers" else 0.017
	var k := (top - o.y) / d.y
	if k < 0.0:
		return t
	var hit := o + d * k
	var half := Vector2(0.035, 0.018) if style == "papers" else Vector2(0.024, 0.014)
	if absf(hit.x) < half.x and absf(hit.z) < half.y:
		return INF
	return t


func ray_hit_precise(origin: Vector3, dir: Vector3, max_t: float) -> float:
	if ray_hit_distance(origin, dir, max_t, 0.0) == INF and open:
		return INF
	return super.ray_hit_precise(origin, dir, max_t)


## A/X en VR : comme F.
func vr_button() -> void:
	toggle()


func toggle() -> void:
	open = not open
	_apply_open(false)


func _apply_open(instant: bool) -> void:
	if _flap == null:
		return
	var a := deg_to_rad(-150.0 if style == "papers" else -115.0) if open else 0.0
	if instant:
		_flap.rotation.x = a
	else:
		create_tween().tween_property(_flap, "rotation:x", a, 0.2)
		_snap.pitch_scale = 1.1 if open else 0.85
		_snap.play()
	refresh_state()


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (open and left() > 0) or _taker.is_grabbed()


func _update_units() -> void:
	if _stack:
		_stack.scale = Vector3(1, maxf(float(count) / _max, 0.04), 1)
		_stack.visible = count > 0


## Feuille vierge / filtre lâché au-dessus du carnet / de la boîte ouverts : il y retourne.
func try_receive(g: VRPickable) -> bool:
	if not open or item == null or g.item == null or g.item == item:
		return false
	var l := item.global_transform.affine_inverse() * g.item.global_position
	if absf(l.x) > 0.06 or absf(l.z) > 0.05 or l.y < -0.01 or l.y > 0.15:
		return false
	if style == "papers":
		var sheet := g as RollingSheet
		if sheet == null or sheet.rolled or sheet.has_filter or sheet.filling() > 0.0 or count >= _max:
			return false
		count += 1
		_update_units()
	else:
		if not (g is RollItem) or g.kind != "filter":
			return false
		var slot: Node3D = null
		for u in _units:
			if not u.visible:
				slot = u
				break
		if slot == null:
			return false
		slot.visible = true
	g.item.queue_free()
	refresh_state()
	return true


## Sort une feuille / un filtre dans la main ; renvoie son Grab.
func take_into(hand: Node3D) -> VRPickable:
	if left() <= 0:
		return null
	var scene := SHEET_SCENE
	var xf := item.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.001 + 0.0045 * (_stack.scale.y if _stack else 1.0) + 0.002, 0.0005))
	if style == "papers":
		count -= 1
		_update_units()
	else:
		scene = FILTER_SCENE
		var u := nearest_unit(hand.global_position)
		var tg: Node3D = _taker._target if _taker else null
		if tg and tg.visible and tg.global_position.distance_to(hand.global_position) < 0.1:
			u = tg
		u.visible = false
		xf = u.global_transform.translated(item.global_basis.y * 0.012)
	var obj := (load(scene) as PackedScene).instantiate() as RigidBody3D
	_taken += 1
	obj.name = "%s_%d" % [item.name, _taken]
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(obj)
	obj.global_transform = xf
	if hand.has_method("is_fingertip"):
		obj.global_position = hand.global_position
	var g := obj.get_node("Grab") as VRPickable
	g.grab(hand)
	refresh_state()
	return g
