extends VRPickable
## Clé du 4x4 avec son trousseau (anneau + 4 breloques qui se balancent).
##
## - Au départ, elle est glissée sous la sangle du pare-soleil conducteur (visible et
##   attrapable seulement pare-soleil rabattu). Lâchée tout près de la sangle, elle y
##   retourne.
## - Hors du contact : objet attrapable comme les autres. Lâchée tout près du barillet
##   (ou en visant le barillet à la souris), elle s'y enfonce.
## - Dans le contact : la saisir puis tourner (VR : tourner le poignet ; souris :
##   glisser vers la droite / la gauche). En position 0, tirer la main de 5 cm la sort.
##   A/X ou F : démarrer / couper le moteur.
## - Trousseau : chaque élément est un pendule (intégration de Verlet dans le monde),
##   donc il réagit au poids, aux accélérations, aux virages et aux bosses. Les
##   breloques ne passent pas à travers le tableau de bord. Posée à plat, le trousseau
##   est étalé à côté de la clé.

const EYELET := Vector3(0.0, 0.0, 0.043)   # trou de l'anneau, repère de la clé
const RING_LEN := 0.024
## [nom, longueur du pendule (m), décalage d'accroche sur l'anneau, angle de vrille (°)]
const CHARMS := [
	["Charm_Opener", 0.034, Vector3(0.0, 0.0, 0.004), 0.0],
	["Charm_Pill", 0.028, Vector3(0.0, 0.0, -0.003), 60.0],
	["Charm_Tag", 0.03, Vector3(0.0, 0.0, 0.0), -35.0],
	["Charm_HouseKey", 0.034, Vector3(0.0, 0.0, -0.005), 110.0],
]

var _ring: Node3D
var _charm_nodes: Array[Node3D] = []
var _ring_p := Vector3.ZERO        # bout bas de l'anneau (monde)
var _ring_prev := Vector3.ZERO
var _cp: Array[Vector3] = []       # centre de chaque breloque (monde)
var _cprev: Array[Vector3] = []
var _sim_ok := false
var _turning := false
var _flying := false
var _grab_ref := Vector3.ZERO
var _grab_angle := 0.0
var _grab_start := Vector3.ZERO
var _last_local := Vector3.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("car_key")
	item_name = "Clé du 4x4"
	rest_up_axis = 0   # posée à plat (épaisseur de la tête vers le haut)
	# l'objet parent est encore en train de créer ses enfants : on attend une image
	_build.call_deferred()


func _build() -> void:
	var parts: Node3D = preload("res://cars/SUV4x4/car_key_parts.glb").instantiate()
	add_child(parts)
	for n in ["Key_Head", "Key_Blade"]:
		var m := parts.get_node(n) as Node3D
		m.reparent(item, false)
		m.transform = Transform3D.IDENTITY
	_ring = parts.get_node("Key_Ring") as Node3D
	_ring.reparent(item, false)
	_ring.top_level = true
	for c in CHARMS:
		var cn := parts.get_node(c[0]) as Node3D
		cn.reparent(item, false)
		cn.top_level = true
		_charm_nodes.append(cn)
		_cp.append(Vector3.ZERO)
		_cprev.append(Vector3.ZERO)
	for n in ["Ign_Bezel", "Ign_Face"]:
		parts.get_node(n).queue_free()
	parts.queue_free()
	# les meshes ont changé (pièces du contact libérées) : contour à reconstruire
	refresh_meshes.call_deferred()
	_lay_flat()


func _ignition():
	var n := item.get_parent()
	return n if n and n.is_in_group("car_ignition") else null


## Pare-soleil dont la sangle tient la clé (ou null).
func _visor():
	var n := item.get_parent()
	return n.get_meta("visor") if n and n.is_in_group("key_holder") else null


func _find_ignition():
	return get_tree().get_first_node_in_group("car_ignition")


# --- Saisie --------------------------------------------------------------------

func _on_grab_begin(hand: Node3D) -> void:
	var ign = _ignition()
	if ign == null:
		super._on_grab_begin(hand)
		return
	_turning = true
	ign.key_held = true
	_grab_angle = ign.key_angle
	_grab_ref = _hand_twist_ref(hand, ign)
	_grab_start = ign.to_local(hand.global_position)
	_last_local = _grab_start


func _on_grab_update(hand: Node3D) -> void:
	if not _turning:
		super._on_grab_update(hand)
		return
	var ign = _ignition()
	if ign == null:
		return
	var local: Vector3 = ign.to_local(hand.global_position)
	# en position 0, tirer la clé vers soi la sort du barillet
	if ign.get_level() == 0 and (local - _grab_start).length() > 0.05:
		ign.key_held = false
		var it: RigidBody3D = ign.eject()
		if it:
			_turning = false
			_take(hand)
			super._on_grab_update(hand)
		return
	if hand.is_in_group("mouse_hands"):
		# souris : glisser la main le long de la tangente de la tête de la clé
		var a: float = float(ign.key_angle)
		var tangent := Vector3(cos(a), -sin(a), 0.0)
		ign.set_key_angle(a + (local - _last_local).dot(tangent) / 0.03)
	else:
		# VR : rotation du poignet autour de l'axe du barillet
		var ref := _hand_twist_ref(hand, ign)
		var d := atan2(_grab_ref.cross(ref).z, _grab_ref.dot(ref))
		ign.set_key_angle(_grab_angle - d)
	_last_local = local


func _on_grab_end(hand: Node3D) -> void:
	if _turning:
		_turning = false
		var ign = _ignition()
		if ign:
			ign.key_held = false
		return
	if hand != _active_hand or is_grabbed():
		super._on_grab_end(hand)
		return
	var ign2 = _find_ignition()
	if ign2 and (ign2.is_near(item.global_position) or _mouse_aims(hand, ign2)):
		_active_hand = null
		ign2.insert(item)
		_sim_ok = false
		return
	for h in get_tree().get_nodes_in_group("key_holder"):
		var visor = h.get_meta("visor")
		if visor and (visor.holder_near(item.global_position) or visor.holder_near(hand.global_position)):
			_active_hand = null
			visor.store_key(item)
			_sim_ok = false
			return
	# la clé ne doit pas se perdre dehors : jetée par la fenêtre, elle retombe sur le siège passager
	var storage := _nearest_storage()
	if storage and not storage.cabin.has_point(storage.to_local(item.global_position)):
		item.global_position = storage.to_global(Vector3(-0.45, 1.0, -0.05))
		hand_velocity = Vector3.ZERO
	super._on_grab_end(hand)


func _mouse_aims(hand: Node3D, ign) -> bool:
	if not hand.is_in_group("mouse_hands"):
		return false
	var cam: Camera3D = hand.get("camera")
	if cam == null:
		return false
	var o := cam.global_position
	var d := (hand.global_position - o).normalized()
	var ip: Vector3 = ign.global_position
	var along := (ip - o).dot(d)
	return along > 0.0 and (o + d * along).distance_to(ip) < 0.045


## Direction de référence de la main projetée dans le plan du barillet (repère du barillet).
func _hand_twist_ref(hand: Node3D, ign) -> Vector3:
	var ib: Basis = (ign.global_basis as Basis).inverse()
	var v := ib * hand.global_basis.x
	v.z = 0.0
	if v.length_squared() < 1e-4:
		v = ib * hand.global_basis.y
		v.z = 0.0
	return v.normalized()


## A/X ou F : dans le contact, démarre ou coupe le moteur. Ailleurs (pare-soleil
## rabattu, rangement, siège...), la clé file toute seule dans le contact (pratique
## pour tester sans casque) ; un second appui démarre.
func toggle() -> void:
	var ign = _ignition()
	if ign:
		ign.toggle()
		return
	if is_grabbed() or _flying:
		return
	var target = _find_ignition()
	if target == null or target.has_key():
		return
	var zone := item.get_parent() as StorageZone
	if zone:
		zone.on_item_taken(item)
	_flying = true
	item.top_level = true
	if item.has_meta("rest_xf"):
		item.remove_meta("rest_xf")
	var from := item.global_transform
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		# la cible suit la voiture pendant le vol
		var to: Transform3D = target.global_transform.translated_local(Vector3(0, 0, 0.04))
		CarStorage.pin_body(item)
		item.global_transform = from.interpolate_with(to, smoothstep(0.0, 1.0, k)), 0.0, 1.0, 0.35)
	tw.tween_callback(func() -> void:
		_flying = false
		target.insert(item)
		_sim_ok = false)


# --- Trousseau -------------------------------------------------------------------

## Breloques étalées à plat à côté de la clé (clé posée, rangée).
func _lay_flat() -> void:
	if _ring == null:
		return
	var piv := item.global_transform * EYELET
	var xf := item.global_transform
	_ring.global_transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, -PI * 0.5), piv)
	var ring_bottom := xf * (EYELET + Vector3(0, 0, RING_LEN))
	# rangée sous la sangle du pare-soleil relevé : breloques couchées sur les côtés de la
	# tête, sans dépasser du bord du pare-soleil ; ailleurs, en éventail au-delà de la tête
	var in_visor := _visor() != null
	for i in _charm_nodes.size():
		var spread := deg_to_rad(-45.0 + 30.0 * i)
		var dir := xf.basis * Vector3(0.0, sin(spread), cos(spread))
		if in_visor:
			var sgn := -1.0 if i % 2 == 0 else 1.0
			dir = xf.basis * Vector3(0.0, sgn, -0.25 - 0.2 * float(i / 2))
		var l: float = CHARMS[i][1]
		var b := _basis_hanging(dir.normalized(), xf.basis.x)
		_charm_nodes[i].global_transform = Transform3D(b, ring_bottom + dir.normalized() * 0.004)
		_cp[i] = ring_bottom + dir.normalized() * l
		_cprev[i] = _cp[i]
	_ring_p = ring_bottom
	_ring_prev = ring_bottom
	_sim_ok = false


## Base dont -Y pointe le long de `down` et X aussi proche que possible de `x_ref`.
static func _basis_hanging(down: Vector3, x_ref: Vector3) -> Basis:
	var y := -down
	var z := x_ref.cross(y)
	if z.length_squared() < 1e-6:
		z = Vector3.FORWARD.cross(y)
	z = z.normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _physics_process(delta: float) -> void:
	if _ring == null:
		return
	var ign = _ignition()
	var visor = _visor()
	if visor:
		enabled = visor.is_down()   # pare-soleil relevé : clé cachée contre le pavillon
	var plane: Array = []
	if ign:
		plane = [ign.global_position, (ign.global_basis as Basis).z]
	elif visor and visor.is_down():
		plane = visor.holder_plane()
	var dangling: bool = ign != null or is_grabbed() or (visor != null and visor.is_down())
	if not dangling:
		if item.freeze:
			_lay_flat()
		return
	var piv := item.global_transform * EYELET
	if not _sim_ok or _ring_p.distance_to(piv) > RING_LEN * 3.0:
		_ring_p = piv + Vector3.DOWN * RING_LEN
		_ring_prev = _ring_p
		for i in _cp.size():
			_cp[i] = _ring_p + Vector3.DOWN * float(CHARMS[i][1])
			_cprev[i] = _cp[i]
		_sim_ok = true
	var g := Vector3(0, -9.81, 0) * delta * delta
	var damp := 0.992
	# anneau
	var nr := _ring_p + (_ring_p - _ring_prev) * damp + g
	_ring_prev = _ring_p
	_ring_p = piv + (nr - piv).normalized() * RING_LEN
	_ring_p = _keep_off(_ring_p, plane, 0.003)
	var key_x := item.global_basis.x
	_ring.global_transform = Transform3D(_basis_hanging((_ring_p - piv).normalized(), key_x), piv)
	# breloques accrochées au bas de l'anneau
	for i in _cp.size():
		var c: Array = CHARMS[i]
		var off: Vector3 = c[2]
		var attach: Vector3 = _ring_p + _ring.global_basis * off
		var l: float = c[1]
		var np := _cp[i] + (_cp[i] - _cprev[i]) * damp + g
		_cprev[i] = _cp[i]
		np = attach + (np - attach).normalized() * l
		np = _keep_off(np, plane, 0.006)
		_cp[i] = np
		var down := (np - attach).normalized()
		var xr := key_x.rotated(down, deg_to_rad(float(c[3])))
		_charm_nodes[i].global_transform = Transform3D(_basis_hanging(down, xr), attach)


## Empêche une breloque de passer derrière une surface (face du tableau de bord pour
## le contact, face du pare-soleil pour la sangle) : plane = [point, normale] ou [].
func _keep_off(p: Vector3, plane: Array, margin: float) -> Vector3:
	if plane.is_empty():
		return p
	var o: Vector3 = plane[0]
	var n: Vector3 = plane[1]
	var d := (p - o).dot(n)
	return p + n * (margin - d) if d < margin else p
