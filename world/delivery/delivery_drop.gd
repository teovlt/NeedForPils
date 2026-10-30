class_name DeliveryDrop
extends Node3D
## Point de livraison : carton ouvert posé par terre (on y lance le sachet) ou boîte aux
## lettres sur son poteau (on y glisse le sachet à la main par la vitre, ou on l'y lance).
## Seul le point de la livraison en cours (DeliveryManager) prend les sachets : une balise
## rose flotte au-dessus, avec un faisceau visible de loin et le nombre de sachets attendus.
##
## Un sachet est pris quand il est lâché près de l'ouverture (try_receive, groupe
## VRPickable.RECEIVERS) ou quand il entre en vol dans la zone de prise (assez large :
## on le lance depuis la voiture qui roule). Partie à deux : un sachet lâché par l'autre
## joueur n'est pas pris ici, c'est lui qui annonce la livraison (Net.rx_delivered).

const GROUP := "delivery_drops"
const MODELS := {"mailbox": "res://props/delivery/mailbox.glb", "carton": "res://props/delivery/carton.glb"}
const PINK := Color(1.0, 0.25, 0.7)
## Distance (m) à l'ouverture sous laquelle un sachet lâché à la main est pris.
const RECEIVE_DIST := {"mailbox": 0.38, "carton": 0.55}
## Zone de prise des sachets lancés : [taille, centre] (repère du point de livraison).
const CATCH_ZONE := {"mailbox": [Vector3(0.75, 0.6, 0.9), Vector3(0, 1.2, 0.05)],
	"carton": [Vector3(1.4, 1.3, 1.4), Vector3(0, 0.6, 0)]}

@export_enum("carton", "mailbox") var kind := "carton"
## Identifiant de la livraison (« lot:3 », « road:7 ») : le même chez les deux joueurs.
var target_id := ""
var active := false
var remaining := 1

var _area: Area3D
var _beacon: Node3D
var _arrow: Node3D
var _count: Label3D
var _door: Node3D
var _flag: Node3D
var _door_t := 0.0          # 0 fermée, 1 ouverte
var _door_hold := 0.0       # temps pendant lequel la porte reste ouverte
var _flag_up := false
var _flag_t := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(VRPickable.RECEIVERS)
	var model := (load(MODELS[kind]) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_door = model.find_child("Door", true, false) as Node3D
	_flag = model.find_child("Flag", true, false) as Node3D
	_decorate(model)
	_area = Area3D.new()
	_area.name = "CatchZone"
	_area.collision_layer = 0
	_area.collision_mask = CarStorage.ITEM_LAYER
	_area.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = CATCH_ZONE[kind][0]
	cs.shape = bs
	cs.position = CATCH_ZONE[kind][1]
	_area.add_child(cs)
	add_child(_area)
	_build_beacon()
	set_active(active, remaining)


## Écritures au marqueur (carton) ou numéro de la boîte aux lettres.
func _decorate(model: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(target_id + str(global_position.snapped(Vector3.ONE)))
	if kind == "carton":
		var l := Label3D.new()
		l.text = [":)", "ICI :)", "FRAGILE", "COLIS"][rng.randi() % 4]
		l.font_size = 64
		l.pixel_size = 0.0022
		l.modulate = Color(0.12, 0.1, 0.1)
		l.outline_size = 0
		l.position = Vector3(0.05, 0.2, 0.201)
		l.rotation_degrees = Vector3(0, 0, rng.randf_range(-12, 12))
		l.set_meta("_vr_outline", true)
		l.visibility_range_end = 60.0   # écriture illisible au-delà
		model.add_child(l)
	else:
		var l := Label3D.new()
		l.text = str(rng.randi_range(2, 148))
		l.font_size = 48
		l.pixel_size = 0.0016
		l.modulate = Color(0.95, 0.92, 0.8)
		l.outline_size = 6
		l.outline_modulate = Color(0.1, 0.1, 0.1)
		l.position = Vector3(0.0967, 1.22, 0.0)
		l.rotation_degrees = Vector3(0, 90, 0)
		l.set_meta("_vr_outline", true)
		l.visibility_range_end = 60.0   # écriture illisible au-delà
		model.add_child(l)


func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "Beacon"
	add_child(_beacon)
	var top := 2.1 if kind == "mailbox" else 1.6
	_arrow = Node3D.new()
	_arrow.position = Vector3(0, top, 0)
	_beacon.add_child(_arrow)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PINK
	mat.emission_enabled = true
	mat.emission = PINK
	mat.emission_energy_multiplier = 2.5
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.0
	cm.height = 0.38
	cm.radial_segments = 4
	cm.rings = 1
	cone.mesh = cm
	cone.material_override = mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(cone)
	# faisceau vertical, de plus en plus transparent vers le haut (visible de loin)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.09
	bm.bottom_radius = 0.09
	bm.height = 36.0
	bm.radial_segments = 6
	bm.rings = 1
	bm.cap_top = false
	bm.cap_bottom = false
	beam.mesh = bm
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;\nuniform vec4 tint : source_color;\nvarying float h;\nvoid vertex() { h = VERTEX.y / 36.0 + 0.5; }\nvoid fragment() { ALBEDO = tint.rgb; ALPHA = tint.a * (1.0 - h) * (1.0 - h); }\n"
	var bmat := ShaderMaterial.new()
	bmat.shader = sh
	bmat.set_shader_parameter("tint", Color(PINK, 0.55))
	beam.material_override = bmat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, top + 18.2, 0)
	_beacon.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = PINK
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position = Vector3(0, top - 0.3, 0)
	_beacon.add_child(light)
	_count = Label3D.new()
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.font_size = 72
	_count.pixel_size = 0.004
	_count.modulate = Color(1, 1, 1)
	_count.outline_size = 14
	_count.outline_modulate = Color(0.45, 0.0, 0.25)
	_count.position = Vector3(0, top + 0.42, 0)
	_count.no_depth_test = false
	_count.set_meta("_vr_outline", true)
	_beacon.add_child(_count)


## Livraison en cours ici (balise, prend les sachets) ou non.
func set_active(on: bool, left := 1) -> void:
	active = on
	remaining = maxi(left, 0)
	if _beacon:
		_beacon.visible = on
		_count.text = ":) x%d" % remaining if remaining > 1 else ":)"


func _physics_process(delta: float) -> void:
	_t += delta
	if _beacon and _beacon.visible:
		_arrow.position.y = (2.1 if kind == "mailbox" else 1.6) + sin(_t * 2.4) * 0.08
		_arrow.rotation.y = _t * 1.5
	# porte de la boîte aux lettres : s'ouvre quand un sachet approche, puis se referme
	if _door:
		var want := 0.0
		if active and _bag_near(0.9):
			want = 1.0
		if _door_hold > 0.0:
			_door_hold -= delta
			want = 1.0
		_door_t = move_toward(_door_t, want, delta * 4.0)
		_door.rotation.x = deg_to_rad(95.0) * _door_t
	if _flag:
		_flag_t = move_toward(_flag_t, 1.0 if _flag_up else 0.0, delta * 3.0)
		_flag.rotation.x = deg_to_rad(90.0) * _flag_t
	if active and _area:
		for b in _area.get_overlapping_bodies():
			_try_catch(b as RigidBody3D)


## Un sachet (tenu ou en vol) est-il près de l'ouverture ?
func _bag_near(dist: float) -> bool:
	var mouth := _mouth()
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		if n is DealerBag and (n as DealerBag).enabled and (n as DealerBag).item:
			if (n as DealerBag).item.global_position.distance_to(mouth) < dist:
				return true
	return false


## Ouverture (repère du monde) : devant la porte de la boîte, au-dessus du carton.
func _mouth() -> Vector3:
	if kind == "mailbox":
		return global_transform * Vector3(0, 1.21, 0.24)
	return global_transform * Vector3(0, 0.36, 0)


## Sachet en vol entré dans la zone de prise.
func _try_catch(body: RigidBody3D) -> void:
	if body == null or body.freeze or body.is_queued_for_deletion():
		return
	var grab := body.get_node_or_null("Grab")
	if not grab is DealerBag or not (grab as DealerBag).enabled or (grab as DealerBag).is_grabbed():
		return
	if body.get_meta("net_remote", false):
		return   # lancé par l'autre joueur : c'est lui qui annonce la livraison
	_deliver(body)


## Objet lâché à la main sur ce point (VRPickable._on_grab_end).
func try_receive(grab) -> bool:
	if not active or not grab is DealerBag or Net.applying_remote:
		return false
	var item: RigidBody3D = (grab as DealerBag).item
	if item == null or item.global_position.distance_to(_mouth()) > RECEIVE_DIST[kind]:
		return false
	_deliver(item)
	return true


func _deliver(bag: RigidBody3D) -> void:
	var mgr := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	if mgr:
		mgr.drop_caught(self, bag)
	else:
		absorb(bag)


## Le sachet rejoint l'intérieur (glisse dans la boîte aux lettres, tombe au fond du carton).
func absorb(bag: RigidBody3D) -> void:
	if bag == null or not is_instance_valid(bag) or bag.get_meta("delivered", false):
		return
	bag.set_meta("delivered", true)
	var grab := bag.get_node_or_null("Grab") as VRInteractable
	if grab:
		grab.enabled = false
	for m in ["free_timer", "rest_xf"]:
		if bag.has_meta(m):
			bag.remove_meta(m)
	ItemPhysics.stop(bag)
	bag.freeze = true
	bag.collision_layer = 0
	bag.collision_mask = 0
	bag.linear_velocity = Vector3.ZERO
	bag.angular_velocity = Vector3.ZERO
	CarStorage.pin_body(bag)
	bag.reparent(self, true)
	bag.top_level = false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(bag.name)
	var end: Transform3D
	if kind == "mailbox":
		_door_hold = 1.2
		_flag_up = true
		end = Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(0, 1.16, -0.05))
	else:
		end = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)),
			Vector3(rng.randf_range(-0.15, 0.15), 0.03, rng.randf_range(-0.1, 0.1)))
	var tw := create_tween()
	tw.tween_property(bag, "transform", end, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if kind == "mailbox":
		tw.tween_callback(bag.hide)
