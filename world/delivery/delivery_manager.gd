class_name DeliveryManager
extends Node
## Livraisons des sachets de smileys du sac à dos (créé par RoadGenerator : « Deliveries »).
##
## Une adresse à la fois, toujours devant la voiture, affichée sur le GPS (distance et
## point rose sur la carte) et marquée sur place par une balise rose (DeliveryDrop) :
## - au bord de la route : boîte aux lettres sur son poteau (plutôt côté gauche, à portée
##   de la vitre du conducteur en se rabattant sur l'autre voie) ou carton posé sur
##   l'accotement, où l'on lance le sachet en passant ;
## - sur le parking d'un des lieux du bord de la route (station-service, motel,
##   supérette, aire de repos, camp : RoadGenerator.get_lots()).
## Une commande = 1 sachet, parfois 2. Adresse dépassée de `miss_distance` m sans avoir
## livré : livraison ratée, on passe à la suivante.
##
## Partie à deux : le conducteur choisit les adresses et compte les livraisons ; le
## copilote reçoit l'adresse avec l'état du monde (NetSession) et prévient le conducteur
## quand il livre lui-même (Net.rx_delivered). Les textes passent par ChaseDirector.

const GROUP := "delivery_manager"

var road: RoadGenerator
var car: Node3D
## Partie à deux, chez le copilote : les adresses viennent du conducteur.
var net_puppet := false

## Délai (s) avant la première adresse, puis entre deux livraisons.
@export var first_delay := 6.0
@export var next_delay := 3.0
## Distance (m, le long de la route) d'une adresse au bord de la route.
@export var roadside_range := Vector2(450.0, 900.0)
## Un lieu du bord de la route est choisi s'il commence dans cette fenêtre devant la voiture.
@export var lot_range := Vector2(220.0, 1700.0)
@export_range(0.0, 1.0) var lot_chance := 0.55
@export_range(0.0, 1.0) var double_chance := 0.25
## Livraison ratée quand la voiture a dépassé l'adresse de cette distance (m).
@export var miss_distance := 120.0

## Livraison en cours : {id, kind, s, lateral, qty, done, place} (vide = aucune).
var target := {}
var delivered := 0
var missed := 0

var _rng := RandomNumberGenerator.new()
var _road_count := 0
var _delay := 0.0
var _timer := 0.0
var _car_s := 0.0
var _drop: DeliveryDrop
var _used_lots := {}


func _ready() -> void:
	add_to_group(GROUP)
	if Net.world_seed("deliveries") != 0:
		_rng.seed = Net.world_seed("deliveries")
	else:
		_rng.randomize()
	_delay = first_delay


func _physics_process(delta: float) -> void:
	if road == null or car == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var here := road.sample_road(car.global_position)
	if not here.get("found", false):
		return
	_car_s = here["s"]
	if not net_puppet:
		if target.is_empty():
			_delay -= 0.25
			if _delay <= 0.0 and _bags_left() > 0:
				_pick()
		elif _car_s > float(target["s"]) + miss_distance:
			_finish(false)
	_update_drop()


# --- Choix de l'adresse ----------------------------------------------------------------

func _pick() -> void:
	var qty := 2 if _rng.randf() < double_chance and _bags_left() >= 2 else 1
	var lot := {}
	for l in road.get_lots():
		var s0 := float(l["s0"])
		if s0 > _car_s + lot_range.x and s0 < _car_s + lot_range.y and not _used_lots.has(l["id"]):
			lot = l
			break
	if not lot.is_empty() and _rng.randf() < lot_chance:
		_used_lots[lot["id"]] = true
		target = {"id": "lot:%d" % lot["id"], "kind": "", "s": float(lot["s0"]) + float(lot["length"]) * 0.5,
			"lateral": 6.0 + float(lot["depth"]) * 0.4, "qty": qty, "done": 0, "place": lot["type"]}
	else:
		var s := _car_s + _rng.randf_range(roadside_range.x, roadside_range.y)
		for l in road.get_lots():   # pas devant l'entrée d'un lieu
			if s > float(l["s0"]) - 40.0 and s < float(l["s1"]) + 40.0:
				s = float(l["s1"]) + 60.0
		var kind := "mailbox" if _rng.randf() < 0.5 else "carton"
		var left := _rng.randf() < (0.65 if kind == "mailbox" else 0.4)
		var lat := (4.55 if kind == "mailbox" else 4.85) * (-1.0 if left else 1.0)
		target = {"id": "road:%d" % _road_count, "kind": kind, "s": s, "lateral": lat, "qty": qty, "done": 0, "place": "route"}
		_road_count += 1
	_drop = null


## Sachets encore à livrer : dans le sac à dos et sortis (pas encore livrés).
func _bags_left() -> int:
	var n := 0
	for r in get_tree().get_nodes_in_group(VRPickable.RECEIVERS):
		if r is Backpack:
			n += (r as Backpack).bags_left()
	for it in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		if it is DealerBag and (it as DealerBag).enabled:
			n += 1
	return n


# --- Point de livraison sur place --------------------------------------------------------

func _update_drop() -> void:
	var id: String = target.get("id", "")
	for d in get_tree().get_nodes_in_group(DeliveryDrop.GROUP):
		var dd := d as DeliveryDrop
		if dd.active and dd.target_id != id:
			dd.set_active(false)
	if id == "":
		_drop = null
		return
	if _drop == null or not is_instance_valid(_drop) or _drop.target_id != id:
		_drop = null
		for d in get_tree().get_nodes_in_group(DeliveryDrop.GROUP):
			if (d as DeliveryDrop).target_id == id and not d.is_queued_for_deletion():
				_drop = d
				break
		if _drop == null and id.begins_with("road:"):
			_drop = _spawn_roadside()
	if _drop:
		var left := int(target["qty"]) - int(target["done"])
		if not _drop.active or _drop.remaining != left:
			_drop.set_active(true, left)


## Boîte aux lettres ou carton au bord de la route, dès que le tronçon est créé.
func _spawn_roadside() -> DeliveryDrop:
	var smp := road.sample_at_s(float(target["s"]))
	if not smp.get("found", false):
		return null
	var lat := float(target["lateral"])
	var pos := road.ground_position(smp, lat)
	var chunk: Node3D = smp["chunk"]
	var d := DeliveryDrop.new()
	d.name = "Drop_%s" % String(target["id"]).replace(":", "_")
	d.kind = target["kind"]
	d.target_id = target["id"]
	# ouverture tournée vers la route (+Z du point de livraison vers l'axe)
	var toward := -(smp["right"] as Vector3) * signf(lat)
	var yaw_jitter := _rng.randf_range(-0.15, 0.15) if target["kind"] == "carton" else 0.0
	var basis := Basis(Vector3.UP.cross(toward).normalized(), Vector3.UP, toward).rotated(Vector3.UP, yaw_jitter)
	chunk.add_child(d)
	d.global_transform = Transform3D(basis, pos + Vector3(0, -0.02, 0))
	return d


# --- Livraison ---------------------------------------------------------------------------

## Un sachet vient d'arriver dans un point de livraison actif, chez ce joueur.
func drop_caught(drop: DeliveryDrop, bag: RigidBody3D) -> void:
	drop.absorb(bag)
	if Net.is_online() and not Net.applying_remote:
		Net.rx_delivered.rpc(drop.target_id, String(bag.name))
	if not net_puppet:
		_count(drop.target_id)


## L'autre joueur a livré un sachet (même point, même sachet chez lui).
func net_delivered(target_id: String, bag_name: String) -> void:
	var drop: DeliveryDrop = null
	for d in get_tree().get_nodes_in_group(DeliveryDrop.GROUP):
		if (d as DeliveryDrop).target_id == target_id:
			drop = d
	var found := get_tree().current_scene.find_children(bag_name, "RigidBody3D", true, false)
	if not found.is_empty():
		var bag := found[0] as RigidBody3D
		var grab := bag.get_node_or_null("Grab") as VRInteractable
		if grab and grab.is_grabbed():
			for h in grab._grab_hands.duplicate():
				grab.release(h)
		if drop:
			drop.absorb(bag)
		else:
			bag.queue_free()
	if not net_puppet:
		_count(target_id)


func _count(id: String) -> void:
	if target.is_empty() or target["id"] != id:
		return
	target["done"] = int(target["done"]) + 1
	if int(target["done"]) >= int(target["qty"]):
		_finish(true)
	else:
		_say("ENCORE UN !", "Le client en veut %d. Lance le suivant." % int(target["qty"]), 2.0)


func _finish(ok: bool) -> void:
	if ok:
		delivered += 1
		var left := _bags_left()
		var sub := "Prochaine adresse sur le GPS." if left > 0 else "Le sac est vide. Plus rien à livrer."
		_say("LIVRÉ !", "%d livraison%s · %s" % [delivered, "s" if delivered > 1 else "", sub], 2.8)
	else:
		missed += 1
		_say("LIVRAISON RATÉE", "Le client attendra. Prochaine adresse sur le GPS.", 2.8)
	if _drop and is_instance_valid(_drop):
		_drop.set_active(false)
	target = {}
	_drop = null
	_delay = next_delay


func _say(title: String, sub: String, duration: float) -> void:
	var director: Node = null
	if get_tree().current_scene:
		director = get_tree().current_scene.get_node_or_null("ChaseDirector")
	if director and not director.get("game_over"):
		director.call("_say", title, sub, duration)
	print("Livraison : ", title, " — ", sub)


# --- Partie à deux et GPS ----------------------------------------------------------------

## État envoyé au copilote avec l'état du monde.
func net_state() -> Array:
	if target.is_empty():
		return [delivered, missed]
	return [delivered, missed, target["id"], target["kind"], target["s"], target["lateral"], target["qty"], target["done"], target["place"]]


func net_apply(st: Array) -> void:
	if st.size() < 2:
		return
	delivered = st[0]
	missed = st[1]
	if st.size() < 9:
		target = {}
		return
	if target.get("id", "") != st[2]:
		_drop = null
	target = {"id": st[2], "kind": st[3], "s": st[4], "lateral": st[5], "qty": st[6], "done": st[7], "place": st[8]}


## Pour le GPS : {dist (m le long de la route), left (sachets), pos (monde) ou null, place, side}.
func gps_info() -> Dictionary:
	if target.is_empty():
		return {}
	var pos = null
	if _drop and is_instance_valid(_drop):
		pos = _drop.global_position
	else:
		var smp := road.sample_at_s(float(target["s"]))
		if smp.get("found", false):
			pos = (smp["point"] as Vector3) + (smp["right"] as Vector3) * float(target["lateral"])
	return {"dist": float(target["s"]) - _car_s, "left": int(target["qty"]) - int(target["done"]), "pos": pos,
		"place": target["place"], "side": signf(float(target["lateral"])), "kind": target["kind"]}
