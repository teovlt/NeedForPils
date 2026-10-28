class_name PillBag
extends VRPickable
## Pochette de congélation transparente à zip, avec une vingtaine de pilules dedans.
##
## - S'attrape et se range comme les autres objets de la voiture (placée au hasard au
##   démarrage par CarStorage).
## - Fermée : A/X (VR) ou F (bureau) en la visant -> le zip s'ouvre en grand : le film
##   du dessus se soulève en arche et l'ouverture s'arrondit (petit bruit de zip). Viser
##   la bande du zip et refaire A/X / F la referme.
## - Ouverte, VR : glisser l'index dans l'ouverture jusqu'aux pilules et presser la
##   gâchette -> la pilule la plus proche se colle au bout du doigt tant que la gâchette
##   reste enfoncée ; la porter à la bouche pour l'avaler (EdiblePickable). Serrer
##   (grip) la main sur les pilules marche aussi.
##   Bureau : viser les pilules dans la pochette et appuyer sur F -> une pilule avalée.
##   On peut aussi en sortir une au clic gauche et la poser ailleurs.
## - Les pilules visibles dans la pochette diminuent à mesure qu'on les prend.
## - Seule la pilule visée (la plus proche de la main) est surlignée ; c'est elle qui sort.
## - Tenue dans une main (VR) : cette main l'ouvre / la ferme avec A/X ; l'autre main ne
##   peut plus attraper la pochette elle-même, seulement les pilules.
## Repère : pochette posée à plat (épaisseur selon Y), zip vers +Z.

const SIZE := Vector2(0.10, 0.14)          # largeur (X), longueur (Z)
const ZIP_Z := 0.052                       # ligne du zip
const MOUTH_H := 0.046                     # hauteur de l'arche du film du dessus, ouverte
const MOUTH_H_BOTTOM := 0.007              # le film du dessous se creuse un peu
const NX := 18                             # subdivisions en largeur (arche bien ronde)
const NZ := 14
const CAPSULE_SCENE := "res://props/items/pill_capsule_item.tscn"
const SMILEY_SCENE := "res://props/items/pill_smiley_item.tscn"
const CAPSULE_MODEL := "res://props/pill_capsule.glb"
const SMILEY_MODEL := "res://props/pill_smiley.glb"

@export var pill_count := 20
@export var open := false

var _pills_root: Node3D
var _pill_nodes: Array[Node3D] = []        # pilules (cachées quand on les a prises)
var _bag_mi: MeshInstance3D
var _zip_mi: MeshInstance3D
var _open_amount := 0.0                    # 0 fermée -> 1 grande ouverte (animé)
var _shape_tween: Tween
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
		grab_with_trigger = true # VR : du bout de l'index, à la gâchette
		super._ready()

	var _target: Node3D           # pilule visée (seule surlignée)

	## Distance à la pilule visible la plus proche (pas aux pilules déjà prises).
	func get_distance_to(global_point: Vector3) -> float:
		return bag.distance_to_pills(global_point)

	func set_hand_distance(hand: Node3D, distance: float) -> void:
		if distance >= 0.0:
			_retarget(bag._nearest_visible(hand.global_position))
		super.set_hand_distance(hand, distance)

	## Le surlignage suit la pilule visée.
	func _retarget(p: Node3D) -> void:
		if p == _target or p == null:
			return
		for m in _meshes:
			if is_instance_valid(m):
				m.material_overlay = null
		_target = p
		mesh_root = p
		refresh_meshes()

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
	# film + zip (surlignés quand on vise / tient la pochette) ; les pilules sont à part :
	# seule celle qu'on vise est surlignée (PillTaker)
	var shell := Node3D.new()
	shell.name = "Shell"
	model.add_child(shell)
	_bag_mi = MeshInstance3D.new()
	_bag_mi.name = "Bag"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.24)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.4
	_bag_mi.material_override = m
	_bag_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(_bag_mi)
	# zip : bandes blanches sur les deux films, trait rouge sur celle du dessus
	_zip_mi = MeshInstance3D.new()
	_zip_mi.name = "Zip"
	var zm := StandardMaterial3D.new()
	zm.vertex_color_use_as_albedo = true
	zm.cull_mode = BaseMaterial3D.CULL_DISABLED
	zm.roughness = 0.5
	_zip_mi.material_override = zm
	shell.add_child(_zip_mi)
	mesh_root = shell
	_rebuild_shape()
	# pilules
	_pills_root = Node3D.new()
	_pills_root.name = "Pills"
	model.add_child(_pills_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in _content_count():
		var holder := _make_content(i, rng)
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


# --- Contenu (surchargé par WeedBag : têtes de weed) ------------------------------

func _content_count() -> int:
	return pill_count


## Une pilule posée dans la pochette (support positionné, modèle dedans).
func _make_content(i: int, rng: RandomNumberGenerator) -> Node3D:
	var is_cap := i % 5 < 3        # 12 gélules, 8 smileys
	var p := (load(CAPSULE_MODEL if is_cap else SMILEY_MODEL) as PackedScene).instantiate() as Node3D
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
	return holder


## Scène de l'objet qu'on sort de la pochette pour ce contenu.
func _content_scene(node: Node3D) -> String:
	var kind: String = (node.get_child(0) as Node3D).get_meta("kind")
	return CAPSULE_SCENE if kind == "capsule" else SMILEY_SCENE


## Hauteur du film du dessus (side = 1) ou du dessous (side = -1) en (x, z).
## Fermée : coussin (dessus bombé au-dessus des pilules, bande du zip à plat).
## Ouverte : vers l'ouverture (+Z), le dessus se soulève en demi-ellipse et le dessous
## se creuse un peu : l'ouverture devient un ovale bien rond.
func _surface_y(x: float, z: float, side: float) -> float:
	var w := SIZE.x
	var l := SIZE.y
	var fx := 1.0 - pow(absf(2.0 * x / w), 4.0)
	var fz := 1.0 - pow(absf(2.0 * (z + 0.006) / (l - 0.012)), 4.0)
	var bulge := 0.011 if z < ZIP_Z - 0.004 else 0.0
	var top := 0.0025 + bulge * maxf(fx, 0.0) * maxf(fz, 0.0)
	var arch := sqrt(maxf(1.0 - pow(2.0 * x / w, 2.0), 0.0))
	var ramp := smoothstep(-0.03, l * 0.5 - 0.014, z)
	if side > 0.0:
		return maxf(top, 0.0025 + _open_amount * MOUTH_H * arch * ramp)
	return -0.002 - 0.0015 * (top - 0.0025) / 0.011 - _open_amount * MOUTH_H_BOTTOM * arch * ramp


func _rebuild_shape() -> void:
	if _bag_mi == null:
		return
	var w := SIZE.x
	var l := SIZE.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		for i in NX:
			for j in NZ:
				var x0 := -w / 2 + w * i / NX
				var x1 := -w / 2 + w * (i + 1) / NX
				var z0 := -l / 2 + l * j / NZ
				var z1 := -l / 2 + l * (j + 1) / NZ
				var a := Vector3(x0, _surface_y(x0, z0, side), z0)
				var b := Vector3(x1, _surface_y(x1, z0, side), z0)
				var c := Vector3(x1, _surface_y(x1, z1, side), z1)
				var d := Vector3(x0, _surface_y(x0, z1, side), z1)
				if side > 0.0:
					for v in [a, d, c, a, c, b]:
						st.add_vertex(v)
				else:
					for v in [a, b, c, a, c, d]:
						st.add_vertex(v)
	# couture : le fond et les deux côtés ; l'ouverture (+Z) n'est fermée que zip fermé
	var segs := []
	for i in NZ:
		var z0 := -l / 2 + l * i / NZ
		var z1 := -l / 2 + l * (i + 1) / NZ
		segs.append([Vector2(-w / 2, z0), Vector2(-w / 2, z1)])
		segs.append([Vector2(w / 2, z0), Vector2(w / 2, z1)])
	segs.append([Vector2(-w / 2, -l / 2), Vector2(w / 2, -l / 2)])
	if _open_amount < 0.05:
		segs.append([Vector2(-w / 2, l / 2), Vector2(w / 2, l / 2)])
	for sg in segs:
		var p0: Vector2 = sg[0]
		var p1: Vector2 = sg[1]
		var a0 := Vector3(p0.x, _surface_y(p0.x, p0.y, -1.0), p0.y)
		var a1 := Vector3(p1.x, _surface_y(p1.x, p1.y, -1.0), p1.y)
		var b0 := Vector3(p0.x, _surface_y(p0.x, p0.y, 1.0), p0.y)
		var b1 := Vector3(p1.x, _surface_y(p1.x, p1.y, 1.0), p1.y)
		for v in [a0, a1, b1, a0, b1, b0]:
			st.add_vertex(v)
	st.generate_normals()
	_bag_mi.mesh = st.commit()
	# bandes du zip, qui suivent les films
	var zt := SurfaceTool.new()
	zt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.95, 0.95, 0.93)
	var red := Color(0.85, 0.08, 0.08)
	_strip(zt, ZIP_Z + 0.002, ZIP_Z + 0.015, 1.0, 0.0008, white)
	_strip(zt, ZIP_Z + 0.0035, ZIP_Z + 0.0055, 1.0, 0.0012, red)
	_strip(zt, ZIP_Z + 0.002, ZIP_Z + 0.015, -1.0, 0.0008, white)
	zt.generate_normals()
	_zip_mi.mesh = zt.commit()


## Bande collée sur un film (côté intérieur décalé de `off`), de z0 à z1.
func _strip(st: SurfaceTool, z0: float, z1: float, side: float, off: float, c: Color) -> void:
	var w := SIZE.x - 0.004
	st.set_color(c)
	for i in NX:
		var x0 := -w / 2 + w * i / NX
		var x1 := -w / 2 + w * (i + 1) / NX
		var a := Vector3(x0, _surface_y(x0, z0, side) + off * side, z0)
		var b := Vector3(x1, _surface_y(x1, z0, side) + off * side, z0)
		var cc := Vector3(x1, _surface_y(x1, z1, side) + off * side, z1)
		var d := Vector3(x0, _surface_y(x0, z1, side) + off * side, z1)
		for v in [a, d, cc, a, cc, b]:
			st.add_vertex(v)


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
	var target := 1.0 if open else 0.0
	if _shape_tween:
		_shape_tween.kill()
	if instant or _bag_mi == null:
		_open_amount = target
		_rebuild_shape()
	else:
		_shape_tween = create_tween()
		_shape_tween.tween_method(_set_open_amount, _open_amount, target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shape_tween.tween_callback(refresh_meshes)   # contours de surbrillance refaits
		if _zip_player:
			_zip_player.pitch_scale = 1.0 if open else 0.85
			_zip_player.play()
	refresh_state()


func _set_open_amount(v: float) -> void:
	_open_amount = v
	_rebuild_shape()


func refresh_state() -> void:
	if _taker:
		_taker.enabled = (open and pills_left() > 0) or _taker.is_grabbed()


## Sort une pilule de la pochette dans la main (VR, clic gauche) ; renvoie son Grab.
func take_pill_into(hand: Node3D) -> VRPickable:
	# la pilule surlignée (visée) en priorité, sinon la plus proche de la main
	var node := _nearest_visible(hand.global_position)
	var tg: Node3D = _taker._target if _taker else null
	if tg and tg.visible and tg.global_position.distance_to(hand.global_position) < 0.1:
		node = tg
	if node == null:
		return null
	node.visible = false
	var pill := (load(_content_scene(node)) as PackedScene).instantiate() as RigidBody3D
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(pill)
	pill.global_transform = node.global_transform
	if hand.has_method("is_fingertip"):
		# prise du bout de l'index : la pilule se colle au bout du doigt
		pill.global_position = hand.global_position
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


## Pochette tenue : seule la main qui la tient y a accès ; l'autre ne prend que les
## pilules (zone PillTaker).
func accepts_hand(hand: Node3D) -> bool:
	if not is_grabbed() or hand in _grab_hands:
		return true
	var owner_hand = hand.get("owner_hand")   # bout de l'index de la main qui tient
	return owner_hand != null and owner_hand in _grab_hands


## Distance (m) entre un point et la pilule visible la plus proche.
func distance_to_pills(global_point: Vector3) -> float:
	var best := INF
	for p in _pill_nodes:
		if p.visible:
			best = minf(best, p.global_position.distance_to(global_point) - 0.006)
	return maxf(best, 0.0)


func _nearest_visible(global_point: Vector3) -> Node3D:
	var node: Node3D = null
	var best := INF
	for p in _pill_nodes:
		if p.visible:
			var d := p.global_position.distance_to(global_point)
			if d < best:
				best = d
				node = p
	return node


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
