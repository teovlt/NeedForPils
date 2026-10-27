class_name PillBag
extends VRPickable
## Pochette de congélation transparente à zip, avec une vingtaine de pilules dedans.
##
## - S'attrape et se range comme les autres objets de la voiture (placée au hasard au
##   démarrage par CarStorage).
## - Fermée : A/X (VR) ou F (bureau) en la visant -> le zip s'ouvre (la lèvre se
##   soulève, petit bruit de zip). Viser la bande du zip et refaire A/X / F la referme.
## - Ouverte, VR : plonger la main dedans (sur les pilules) et serrer -> une pilule
##   sort dans la main ; la porter à la bouche pour l'avaler (EdiblePickable).
##   Bureau : viser les pilules dans la pochette et appuyer sur F -> une pilule avalée.
##   On peut aussi en sortir une au clic gauche et la poser ailleurs.
## - Les pilules visibles dans la pochette diminuent à mesure qu'on les prend.
## Repère : pochette posée à plat (épaisseur selon Y), zip vers +Z.

const SIZE := Vector2(0.10, 0.14)          # largeur (X), longueur (Z)
const ZIP_Z := 0.052                       # ligne du zip
const CAPSULE_SCENE := "res://props/items/pill_capsule_item.tscn"
const SMILEY_SCENE := "res://props/items/pill_smiley_item.tscn"
const CAPSULE_MODEL := "res://props/pill_capsule.glb"
const SMILEY_MODEL := "res://props/pill_smiley.glb"

@export var pill_count := 20
@export var open := false

var _pills_root: Node3D
var _pill_nodes: Array[Node3D] = []        # pilules visibles (la dernière part en premier)
var _lip: Node3D
var _taker: Taker
var _zip_player: AudioStreamPlayer3D
var _bag_built := false


## Zone de saisie « les pilules dans la pochette » (active seulement pochette ouverte).
## Fait l'intermédiaire : une vraie pilule (EdiblePickable) est créée dans la main et
## suit les mouvements que la main envoie à la zone.
class Taker:
	extends VRInteractable
	var bag
	var _held := {}     # main -> Grab de la pilule tenue

	func _ready() -> void:
		highlight_distance = 0.12
		grab_distance = 0.045    # (marge de visée souris = 30 % : 1,3 cm)
		outline_width = 0.0015
		pick_bonus = 0.024       # devant la pochette quand la main est sur les pilules
		super._ready()

	func _on_grab_begin(hand: Node3D) -> void:
		var g = bag.take_pill_into(hand)
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
		bag.refresh_state()

	func toggle() -> void:
		for h in _held:   # pilule sortie et tenue : F l'avale
			var g = _held[h]
			if g and is_instance_valid(g) and g.has_method("toggle"):
				g.toggle()
				return
		bag.eat_from_bag()


func _ready() -> void:
	super._ready()
	rest_up_axis = 1
	friction = 0.7
	_build.call_deferred()


## Boîte englobante fixe (repère de l'objet) : le maillage est construit en différé, et
## la boîte calculée sur les maillages pouvait être lue avant (vide) : la pochette était
## alors rangée de travers, à moitié dans le fond du rangement.
func get_local_aabb() -> AABB:
	return AABB(Vector3(-SIZE.x * 0.5, -0.0145, -SIZE.y * 0.5), Vector3(SIZE.x, 0.029, SIZE.y))


func _build() -> void:
	if _bag_built:
		return
	_bag_built = true
	var model := item.get_node_or_null("Model") as Node3D
	if model == null:
		model = Node3D.new()
		model.name = "Model"
		item.add_child(model)
	model.add_child(_bag_mesh())
	# zip : bande blanche dessous, et sur la lèvre (bande blanche + trait rouge) qui
	# se soulève à l'ouverture
	var white := _mat(Color(0.95, 0.95, 0.93, 0.85), true)
	var red := _mat(Color(0.85, 0.08, 0.08), false)
	var grey := _mat(Color(0.35, 0.35, 0.38), false)
	model.add_child(_box(Vector3(SIZE.x - 0.004, 0.0012, 0.013), Vector3(0, -0.0018, ZIP_Z + 0.008), white))
	_lip = Node3D.new()
	_lip.name = "Lip"
	_lip.position = Vector3(0, 0.0, ZIP_Z - 0.004)
	model.add_child(_lip)
	_lip.add_child(_box(Vector3(SIZE.x - 0.004, 0.0012, 0.013), Vector3(0, 0.0032, 0.012), white))
	_lip.add_child(_box(Vector3(SIZE.x - 0.002, 0.0016, 0.0016), Vector3(0, 0.0036, 0.004), red))
	for k in 4:   # petites inscriptions grises sur la bande blanche
		_lip.add_child(_box(Vector3(0.008, 0.0004, 0.003), Vector3(-0.03 + k * 0.02, 0.0040, 0.013), grey))
	# pilules
	_pills_root = Node3D.new()
	_pills_root.name = "Pills"
	model.add_child(_pills_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cap := load(CAPSULE_MODEL) as PackedScene
	var smi := load(SMILEY_MODEL) as PackedScene
	for i in pill_count:
		var is_cap := i % 5 < 3        # 12 gélules, 8 smileys
		var p := (cap if is_cap else smi).instantiate() as Node3D
		p.set_meta("kind", "capsule" if is_cap else "smiley")
		var holder := Node3D.new()
		holder.add_child(p)
		if is_cap:
			p.scale = Vector3.ONE * 1.5
			p.position = Vector3(-0.0075, 0, 0)          # modèle de 1 cm, origine au bout
		else:
			p.scale = Vector3.ONE * 1.3
		var layer := float(i / 9)
		holder.position = Vector3(rng.randf_range(-0.038, 0.038), -0.0005 + layer * 0.0045 + rng.randf() * 0.0015,
				rng.randf_range(-0.055, ZIP_Z - 0.024))   # laisse libre la bande du zip
		holder.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		_pills_root.add_child(holder)
		_pill_nodes.append(holder)
	# zone de saisie des pilules
	_taker = Taker.new()
	_taker.name = "PillTaker"
	_taker.bag = self
	_taker.mesh_root = _pills_root
	item.add_child(_taker)
	_zip_player = AudioStreamPlayer3D.new()
	_zip_player.stream = _make_zip_sound()
	_zip_player.unit_size = 1.5
	item.add_child(_zip_player)
	refresh_meshes()
	_apply_open(true)


func _bag_mesh() -> MeshInstance3D:
	# coussin : dessus bombé, dessous presque plat, reliés par une couture
	var nx := 10
	var nz := 12
	var w := SIZE.x
	var l := SIZE.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := func(x: float, z: float) -> float:
		var fx := 1.0 - pow(absf(2.0 * x / w), 4.0)
		var fz := 1.0 - pow(absf(2.0 * (z + 0.006) / (l - 0.012)), 4.0)
		var bulge := 0.011 if z < ZIP_Z - 0.004 else 0.0
		return 0.0025 + bulge * maxf(fx, 0.0) * maxf(fz, 0.0)
	for side in [1.0, -1.0]:
		for i in nx:
			for j in nz:
				var x0 := -w / 2 + w * i / nx
				var x1 := -w / 2 + w * (i + 1) / nx
				var z0 := -l / 2 + l * j / nz
				var z1 := -l / 2 + l * (j + 1) / nz
				var y := func(x: float, z: float) -> float:
					return top.call(x, z) if side > 0.0 else -0.002 - 0.0015 * (top.call(x, z) - 0.0025) / 0.011
				var a := Vector3(x0, y.call(x0, z0), z0)
				var b := Vector3(x1, y.call(x1, z0), z0)
				var c := Vector3(x1, y.call(x1, z1), z1)
				var d := Vector3(x0, y.call(x0, z1), z1)
				if side > 0.0:
					for v in [a, d, c, a, c, b]:
						st.add_vertex(v)
				else:
					for v in [a, b, c, a, c, d]:
						st.add_vertex(v)
	# couture du tour
	var ring := [Vector3(-w / 2, 0, -l / 2), Vector3(w / 2, 0, -l / 2), Vector3(w / 2, 0, l / 2), Vector3(-w / 2, 0, l / 2)]
	for k in 4:
		var p0: Vector3 = ring[k]
		var p1: Vector3 = ring[(k + 1) % 4]
		var up := Vector3(0, 0.0025, 0)
		var dn := Vector3(0, -0.002, 0)
		for v in [p0 + dn, p1 + dn, p1 + up, p0 + dn, p1 + up, p0 + up]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Bag"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.24)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.4
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	return mi


func _mat(c: Color, alpha: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Visée souris : pochette ouverte, viser les pilules désigne les pilules (PillTaker),
## pas la pochette ; on attrape / referme la pochette en visant le zip ou les bords.
func ray_hit_distance(origin: Vector3, dir: Vector3, max_t: float, margin: float) -> float:
	var t := super.ray_hit_distance(origin, dir, max_t, margin)
	if t == INF or not open or pills_left() == 0 or item == null:
		return t
	var inv := item.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.y) < 1e-4:
		return t
	var k := (0.006 - o.y) / d.y          # point visé sur le dessus de la pochette
	if k < 0.0:
		return t
	var hit := o + d * k
	if absf(hit.x) < SIZE.x * 0.45 and hit.z > -SIZE.y * 0.47 and hit.z < ZIP_Z - 0.01:
		return INF
	return t


# --- Ouverture / pilules ------------------------------------------------------

func pills_left() -> int:
	var n := 0
	for p in _pill_nodes:
		if p.visible:
			n += 1
	return n


## Visée sur la pochette (sur le zip, ou partout si elle est fermée) : ouvre / ferme.
func toggle() -> void:
	open = not open
	_apply_open(false)


func _apply_open(instant: bool) -> void:
	if _lip:
		var a := deg_to_rad(-32.0 if open else 0.0)
		if instant:
			_lip.rotation.x = a
		else:
			create_tween().tween_property(_lip, "rotation:x", a, 0.25)
			if _zip_player:
				_zip_player.pitch_scale = 1.0 if open else 0.85
				_zip_player.play()
	refresh_state()


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (open and pills_left() > 0) or _taker.is_grabbed()


## Sort une pilule de la pochette dans la main (VR, clic gauche) ; renvoie son Grab.
func take_pill_into(hand: Node3D) -> VRPickable:
	var node := _last_visible()
	if node == null:
		return null
	node.visible = false
	var kind: String = (node.get_child(0) as Node3D).get_meta("kind")
	var pill := (load(CAPSULE_SCENE if kind == "capsule" else SMILEY_SCENE) as PackedScene).instantiate() as RigidBody3D
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(pill)
	pill.global_transform = node.global_transform
	var g := pill.get_node("Grab") as VRPickable
	g.grab(hand)
	refresh_state()
	return g


## F en visant les pilules (bureau) : une pilule avalée directement.
func eat_from_bag() -> void:
	var node := _last_visible()
	if node == null:
		return
	node.visible = false
	EdiblePickable.swallow(get_tree())
	refresh_state()


func _last_visible() -> Node3D:
	for i in range(_pill_nodes.size() - 1, -1, -1):
		if _pill_nodes[i].visible:
			return _pill_nodes[i]
	return null


static func _make_zip_sound() -> AudioStreamWAV:
	# « zzzip » : suite rapide de petits clics filtrés
	var rate := 22050
	var n := int(rate * 0.32)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var tooth := fmod(t * (90.0 + 60.0 * t), 1.0) < 0.12   # dents du zip
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.35
		var s := (lp * 0.5 + (noise * 0.9 if tooth else 0.0)) * sin(PI * t / 0.32) * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
