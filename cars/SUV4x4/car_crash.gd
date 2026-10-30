class_name CarCrash
extends Node
## Secousses et accidents du 4x4 (enfant de la voiture, créé par SUV4x4).
##
## - Bosse, trou, dos d'âne, retombée d'un saut (suspension qui encaisse d'un coup) :
##   les objets en vrac et ceux des compartiments sautillent un peu (quelques
##   centimètres, ils ne sortent pas de l'habitacle ni d'un compartiment fermé). Une
##   grosse secousse peut ouvrir l'accoudoir, plus rarement la boîte à gants.
## - Accident (la voiture perd d'un coup beaucoup de vitesse : arbre, rocher,
##   voiture...) : choc sonore, manettes qui vibrent, « CHOC ! » au combiné, tout ce qui
##   traîne est projeté vers l'avant. Au-delà de `lids_kmh`, l'accoudoir et la boîte à
##   gants s'ouvrent ; au-delà de `door_kmh`, une portière s'ouvre.
## - Au-delà de `eject_kmh` sans ceinture : on traverse le pare-brise (éclats de verre,
##   vol plané, noir), fin de partie « À TRAVERS LE PARE-BRISE ». Attaché, on s'en sort.
##   Partie à deux : le copilote sans ceinture est éjecté de la même façon (fin de
##   partie pour les deux).
## Seul le conducteur détecte (sa voiture simule) ; chaque secousse ou accident est
## rejoué chez le copilote (Net.perform) avec les mêmes tirages.

signal crashed(kmh: float)

## Vitesse de la suspension (m/s) à partir de laquelle les objets sautent, et pour
## laquelle la secousse est maximale (route lisse : < 0,5 ; dos d'âne de 12 cm à
## 55 km/h : ~4,5). En dessous de `jolt_min_kmh`, rien (la voiture qui s'affaisse au
## démarrage ou en freinant fort n'est pas une bosse).
@export var jolt_range := Vector2(1.4, 3.5)
@export var jolt_min_kmh := 12.0
@export var jolt_cooldown := 0.3
## Saut des objets pour une secousse maximale (m/s vers le haut, ~6 cm).
@export var jolt_kick := 1.1
## Perte de vitesse (km/h en `crash_window` s) à partir de laquelle c'est un accident.
@export var crash_kmh := 20.0
@export var crash_window := 0.15
## Accoudoir et boîte à gants ouverts, portière ouverte, éjection sans ceinture (km/h
## perdus dans le choc).
@export var lids_kmh := 25.0
@export var door_kmh := 45.0
@export var eject_kmh := 60.0
## Durée du vol plané avant le noir complet (s).
@export var eject_time := 1.1

var car: SUV4x4
## Tests : secousses, dernier choc (km/h perdus), éjecté (joueur local).
var jolts := 0
var last_crash_kmh := 0.0
var ejected := false

var _t := 0.0
var _hist: Array = []       # [temps, vitesse horizontale] des derniers pas physiques
var _jolt_cool := 0.0
var _crash_cool := 0.0
var _crash_player: AudioStreamPlayer3D
var _glass_player: AudioStreamPlayer3D
var _view: Node3D           # point de vue éjecté (enfant de la voiture)
var _eject_t := -1.0
var _eject_from: Transform3D
var _eject_to: Transform3D
var _eject_v := Vector3.ZERO

const RATE := 22050


func _ready() -> void:
	car = get_parent() as SUV4x4
	_crash_player = AudioStreamPlayer3D.new()
	_crash_player.name = "CrashSound"
	GeneratedSound.make_later(_make_crash, _crash_player, &"stream")
	_crash_player.position = Vector3(0.0, 1.0, 1.4)
	_crash_player.unit_size = 6.0
	add_child(_crash_player)
	_glass_player = AudioStreamPlayer3D.new()
	_glass_player.name = "GlassSound"
	GeneratedSound.make_later(_make_glass, _glass_player, &"stream")
	_glass_player.position = Vector3(0.0, 1.45, 0.74)
	_glass_player.unit_size = 5.0
	add_child(_glass_player)


func _physics_process(delta: float) -> void:
	_t += delta
	_jolt_cool -= delta
	_crash_cool -= delta
	if car == null or car.net_puppet or ejected:
		return
	_detect_jolt()
	_detect_crash()


func _process(delta: float) -> void:
	if _eject_t >= 0.0:
		_update_eject(delta)


# --- Détection (conducteur) ------------------------------------------------------------

func _detect_jolt() -> void:
	var s := clampf((car.road_jolt - jolt_range.x) / (jolt_range.y - jolt_range.x), 0.0, 1.0)
	if s <= 0.0 or _jolt_cool > 0.0 or absf(car.forward_speed) * 3.6 < jolt_min_kmh:
		return
	_jolt_cool = jolt_cooldown
	var console := s > 0.7 and randf() < 0.45
	var glove := s > 0.85 and randf() < 0.3
	Net.perform(self, &"jolt", [s, console, glove])


func _detect_crash() -> void:
	var v := car.linear_velocity
	v.y = 0.0
	_hist.append([_t, v])
	while _hist.size() > 1 and _t - float(_hist[0][0]) > crash_window:
		_hist.pop_front()
	if _crash_cool > 0.0:
		return
	var lost := 0.0
	var before := 0.0
	for h in _hist:
		var old := h[1] as Vector3
		if v.length() >= old.length():
			continue   # elle n'a pas ralenti (accélération, voiture relancée)
		var d := (old - v).length()
		if d > lost:
			lost = d
			before = (h[1] as Vector3).length()
	var kmh := lost * 3.6
	if kmh < crash_kmh:
		return
	_crash_cool = 1.5
	_hist.clear()
	var violent := kmh >= eject_kmh
	var eject_driver: bool = violent and car.seatbelt != null and not car.seatbelt.is_buckled()
	var eject_copilot: bool = violent and Net.is_online() and car.seatbelts.size() > 1 and not car.seatbelts[1].is_buckled()
	var door := randi() % 4 if kmh >= door_kmh else -1
	Net.perform(self, &"crash", [kmh, before * 3.6, eject_driver, eject_copilot, door])


# --- Effets (conducteur et copilote) -------------------------------------------------

## Secousse `strength` (0-1) : les objets sautillent ; couvercles qui s'ouvrent (tirés
## au sort par le conducteur).
func jolt(strength: float, open_console: bool, open_glovebox: bool) -> void:
	jolts += 1
	kick_items(Vector3.UP * strength * jolt_kick, 0.3 * strength, 0.5 + 0.5 * strength)
	if open_console:
		_open_hinge(car.get_node_or_null("ConsoleLid"))
	if open_glovebox:
		_open_hinge(car.get_node_or_null("GloveboxLid"))


## Accident : `kmh` perdus dans le choc, `speed_kmh` vitesse juste avant.
func crash(kmh: float, speed_kmh: float, eject_driver: bool, eject_copilot: bool, door: int) -> void:
	last_crash_kmh = kmh
	crashed.emit(kmh)
	var k := clampf(kmh / 60.0, 0.3, 1.0)
	_crash_player.volume_db = linear_to_db(k) + 4.0
	_crash_player.pitch_scale = randf_range(0.9, 1.05)
	_crash_player.play()
	car.set("_hit_flash", 2.0)
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(1.0, 0.15 + 0.35 * k)
	# tout ce qui traîne part vers l'avant (le pare-brise et la planche l'arrêtent)
	kick_items(Vector3(0.0, 0.5, 1.0) * minf(kmh / 25.0, 1.0) * 3.0, 0.6, 1.0)
	if kmh >= lids_kmh:
		_open_hinge(car.get_node_or_null("ConsoleLid"))
		_open_hinge(car.get_node_or_null("GloveboxLid"))
	if door >= 0:
		var doors := car.get_node("Doors").get_children()
		_open_hinge(doors[door % doors.size()])
	if eject_driver or eject_copilot:
		_shatter_windshield()
	if (eject_driver and not Net.is_copilot()) or (eject_copilot and Net.is_copilot()):
		_eject(speed_kmh)
	if (eject_driver or eject_copilot) and not Net.is_copilot():
		var dir := get_tree().get_first_node_in_group(ChaseDirector.GROUP) as ChaseDirector
		if dir:
			get_tree().create_timer(eject_time + 0.2).timeout.connect(
					dir.end_crash.bind(eject_copilot and not eject_driver, speed_kmh))


## Donne un élan (repère de la voiture, m/s) aux objets posés en vrac et rangés dans les
## compartiments, avec un peu de hasard ; `spread` : part horizontale au hasard,
## `chance` : probabilité que chaque objet bouge.
func kick_items(impulse: Vector3, spread: float, chance: float) -> void:
	var cb := car.global_basis.orthonormalized()
	for holder in car.find_children("*", "Node3D", true, false):
		if not (holder is CarStorage or holder is StorageZone):
			continue
		var to_local := (holder as Node3D).global_basis.orthonormalized().inverse() * cb
		for c in holder.get_children():
			if not c is RigidBody3D or randf() > chance:
				continue
			var grab := c.get_node_or_null("Grab") as VRPickable
			if grab and grab.is_grabbed():
				continue
			var st := ItemPhysics.get_state(c)
			if st.is_empty():
				continue
			var v := impulse * randf_range(0.6, 1.0) + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * spread
			ItemPhysics.kick(st, to_local * v)


func _open_hinge(n: Node) -> void:
	var h := n as VRHingeInteractable
	if h and not h.is_grabbed() and not h.is_open():
		h.open()


# --- Pare-brise et éjection ------------------------------------------------------------

func _shatter_windshield() -> void:
	_glass_player.play()
	var rain := car.get_node_or_null("WindshieldRain") as Node3D
	if rain:
		rain.visible = false
	var p := CPUParticles3D.new()
	p.name = "WindshieldShards"
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 90
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.65, 0.05, 0.3)
	p.direction = Vector3(0.0, 0.4, 1.0)
	p.spread = 40.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.025)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.88, 0.95, 0.55)
	m.metallic_specular = 1.0
	m.roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.position = Vector3(0.0, 1.45, 0.74)
	car.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## Le joueur local traverse le pare-brise : vol plané vers l'avant, noir, puis allongé
## par terre devant la voiture, tourné vers elle.
func _eject(speed_kmh: float) -> void:
	if ejected:
		return
	ejected = true
	var cam := get_viewport().get_camera_3d()
	var origin: Node3D = car.get("_xr_origin")
	var rig: Node3D = origin if origin and is_instance_valid(origin) and cam and origin.is_ancestor_of(cam) else cam
	if rig == null:
		return
	_view = Node3D.new()
	_view.name = "EjectedView"
	car.add_child(_view)
	_view.global_transform = rig.get_parent_node_3d().global_transform if rig == origin else rig.global_transform
	rig.reparent(_view, true)
	_eject_from = _view.transform
	# point d'arrivée : quelques mètres devant le capot, au ras du sol, regard vers la voiture
	var fwd := clampf(speed_kmh / 100.0, 0.5, 1.4) * 9.0
	var side := randf_range(-1.5, 1.5)
	var land := Vector3(_eject_from.origin.x * 0.3 + side, 0.0, 2.6 + fwd)
	var g := car.to_global(land)
	var ray := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 6.0, g + Vector3.DOWN * 12.0)
	ray.exclude = [car.get_rid()]
	var hit := car.get_world_3d().direct_space_state.intersect_ray(ray)
	land.y = (car.to_local(hit.position).y if hit else land.y) + 0.22
	var back := Basis(Vector3.UP, PI) * _eject_from.basis   # regard vers la voiture
	back = Basis(back.z.normalized(), deg_to_rad(randf_range(8.0, 14.0)) * signf(side + 0.01)) * back
	_eject_to = Transform3D(back.orthonormalized(), land)
	_eject_v = Vector3(side * 0.6, 4.2, fwd / eject_time * 1.35)
	_eject_t = 0.0


func _update_eject(delta: float) -> void:
	_eject_t += delta
	var t := _eject_t
	if t < eject_time:
		# vol : lancé vers l'avant et vers le haut, la tête bascule vers l'avant
		var p := _eject_from.origin + _eject_v * t + Vector3(0.0, -4.9, 0.0) * t * t
		p.z -= 0.5 * (_eject_v.z * 0.6 / eject_time) * t * t   # l'air freine
		var pitch := deg_to_rad(110.0) * t / eject_time
		var b := Basis(Vector3.RIGHT, pitch) * _eject_from.basis
		_view.transform = Transform3D(b.orthonormalized(), p)
		_set_curtain(smoothstep(0.25, eject_time * 0.9, t))
	else:
		_view.transform = _eject_to
		# on rouvre un peu les yeux, par terre (ChaseDirector pose le rideau de fin)
		if t > eject_time + 1.5:
			_eject_t = -1.0


func _set_curtain(v: float) -> void:
	var add := get_tree().get_first_node_in_group(PillAddiction.GROUP) as PillAddiction
	if add:
		add.curtain = maxf(add.curtain, v)


# --- Sons générés par code ------------------------------------------------------------

## Choc : boum sourd + tôle froissée (bruit filtré qui crépite).
static func _make_crash() -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var boom := sin(TAU * (38.0 + 50.0 * exp(-t * 12.0)) * t) * exp(-t * 5.0)
		var noise := randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.25
		lp2 += (lp - lp2) * 0.5
		var crackle := 1.0 if randf() < 0.02 * exp(-t * 3.0) else 0.0
		var metal := (lp - lp2) * 2.5 * exp(-t * 3.5) + crackle * randf_range(-0.8, 0.8)
		s[i] = clampf(boom * 0.9 + metal * 0.7, -1.0, 1.0)
	return _wav(s)


## Pare-brise qui éclate : craquement puis pluie de petits tintements.
static func _make_glass() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var pings: Array = []
	for k in 40:
		pings.append([randf_range(0.0, 1.0) * randf_range(0.0, 1.0), randf_range(2500.0, 7000.0), randf_range(0.15, 0.5)])
	for i in n:
		var t := float(i) / RATE
		var v := randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.8
		for pg in pings:
			var dt: float = t - float(pg[0])
			if dt >= 0.0 and dt < 0.12:
				v += sin(TAU * float(pg[1]) * dt) * exp(-dt * 40.0) * float(pg[2])
		s[i] = clampf(v * 0.7, -1.0, 1.0)
	return _wav(s)


static func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
