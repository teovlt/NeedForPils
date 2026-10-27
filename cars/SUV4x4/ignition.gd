extends Node3D
## Contacteur à clé (Neiman) sur le tableau de bord, à droite de la colonne.
##
## Repère du noeud : origine = face du barillet, +Z sort du tableau de bord vers le
## conducteur. La clé (vr_car_key.gd) s'y insère quand on la lâche tout près.
## Positions (sens horaire vu du conducteur) :
##   0 : arrêt (la clé ne sort qu'ici)   I : accessoires   II : contact (combiné allumé)
##   III : démarreur, à ressort : lâchée, la clé revient sur II.
## Tenir la clé sur III fait tourner le démarreur ; le moteur part au bout de
## `crank_time` s. Revenir sur I ou 0 coupe le moteur.

const GROUP := "car_ignition"
const LEVEL_DEG := [0.0, 35.0, 70.0, 100.0]   # 0, I, II, III

@export var crank_time := 0.8

var car: Node3D
var key_item: RigidBody3D          # clé insérée (ou null)
var key_angle := 0.0               # radians, sens horaire vu du conducteur
var key_held := false              # la main tient la clé (pas de cran ni de ressort)
var _crank_timer := 0.0
var _insert_t := 1.0
var _auto_target := -1.0           # rotation automatique (F / A-X / touche M)
var _auto_hold := 0.0
var _face: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	var parts: Node3D = preload("res://cars/SUV4x4/car_key_parts.glb").instantiate()
	add_child(parts)
	for n in ["Ign_Bezel", "Ign_Face"]:
		var m := parts.get_node(n) as Node3D
		m.reparent(self, false)
		m.transform = Transform3D.IDENTITY
	_face = get_node("Ign_Face")
	parts.queue_free()
	# repères gravés autour du barillet
	var labels := ["0", "I", "II", "III"]
	for i in 4:
		var l := Label3D.new()
		l.text = labels[i]
		l.font_size = 24
		l.pixel_size = 0.00028
		l.outline_size = 0
		l.modulate = Color(0.85, 0.87, 0.9) if i < 3 else Color(1.0, 0.55, 0.2)
		l.double_sided = false
		var a := deg_to_rad(LEVEL_DEG[i])
		l.position = Vector3(sin(a), cos(a), 0.0) * 0.029 + Vector3(0, 0, 0.002)
		add_child(l)


## 0 arrêt, 1 accessoires, 2 contact, 3 démarreur.
func get_level() -> int:
	if key_item == null:
		return 0
	var d := rad_to_deg(key_angle)
	if d > 85.0:
		return 3
	if d > 52.0:
		return 2
	if d > 17.0:
		return 1
	return 0


func has_key() -> bool:
	return key_item != null


## La clé est-elle assez près du barillet pour y entrer ?
func is_near(world_pos: Vector3, radius := 0.06) -> bool:
	return global_position.distance_to(world_pos) < radius


func insert(item: RigidBody3D, level := 0, instant := false) -> void:
	key_item = item
	item.reparent(self, true)
	item.top_level = false
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	if item.has_meta("rest_xf"):
		item.remove_meta("rest_xf")
	key_angle = deg_to_rad(LEVEL_DEG[level])
	_insert_t = 1.0 if instant else 0.0
	_place_key()


## Retire la clé (seulement en position 0). Rend l'objet, ou null.
func eject() -> RigidBody3D:
	if key_item == null or get_level() != 0:
		return null
	var it := key_item
	key_item = null
	key_angle = 0.0
	_place_key()
	return it


## F / A-X sur la clé, touche M : démarre si le moteur est coupé, sinon coupe.
func toggle() -> void:
	if key_item == null:
		return
	if car and car.get("engine_state") == 2:
		_auto_target = 0.0
	else:
		_auto_target = deg_to_rad(LEVEL_DEG[3])
		_auto_hold = crank_time + 0.25


func set_key_angle(a: float) -> void:
	key_angle = clampf(a, 0.0, deg_to_rad(LEVEL_DEG[3]))
	_auto_target = -1.0


func _place_key() -> void:
	_face.transform.basis = Basis(Vector3.BACK, -key_angle)
	if key_item:
		CarStorage.pin_body(key_item)
		var slide := Vector3(0, 0, 0.035 * (1.0 - _insert_t))
		key_item.transform = Transform3D(Basis(Vector3.BACK, -key_angle), slide)


func _physics_process(delta: float) -> void:
	if key_item:
		_insert_t = minf(_insert_t + delta / 0.18, 1.0)
		if _auto_target >= 0.0:
			key_angle = move_toward(key_angle, _auto_target, deg_to_rad(260.0) * delta)
			if is_equal_approx(key_angle, _auto_target):
				if _auto_hold > 0.0:
					_auto_hold -= delta
				else:
					_auto_target = -1.0
		elif not key_held:
			# ressort du démarreur, puis crans
			var deg := rad_to_deg(key_angle)
			var target := 70.0 if deg > 52.0 else (35.0 if deg > 17.0 else 0.0)
			key_angle = move_toward(key_angle, deg_to_rad(target), deg_to_rad(300.0) * delta)
		_place_key()
	_update_engine(delta)


func _update_engine(delta: float) -> void:
	if car == null:
		return
	var level := get_level()
	var state: int = car.get("engine_state")
	if level == 3 and state != 2:
		_crank_timer += delta
		car.set("engine_state", 2 if _crank_timer >= crank_time else 1)
	else:
		_crank_timer = 0.0
		if state == 1:
			car.set("engine_state", 0)   # démarreur relâché trop tôt
		elif state == 2 and level < 2:
			car.set("engine_state", 0)   # contact coupé
