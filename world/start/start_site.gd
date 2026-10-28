extends Node3D
## Lieu de départ : la voiture démarre garée sur un des 4 lieux, tiré au hasard par
## RoadGenerator (_plan_site) : supérette désaffectée, aire de repos, camp de
## caravanes (« rednecks »), motel malfamé. Tout est construit par code en low poly
## abîmé (formes simples, couleurs passées, rouille, tags), avec des collisions sur
## les bâtiments et les gros objets.
##
## Repère : X le long de la route (sens de circulation), Z vers l'extérieur (le lieu
## s'étend de z = 0, à 6 m de l'axe de la route, jusqu'à z = depth). L'entrée rejoint
## l'accotement en z = -1,7. La voiture est posée sur le lieu, moteur coupé, tournée
## vers la sortie.

var site_type := "superette"
var depth := 27.0
var length := 38.0
var car: Node3D

var _mats := {}
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _neon: Array[Label3D] = []      # lettres qui clignotent (motel)
var _flicker: Array = []            # [noeud émissif, lumière ou null]
var _fire: OmniLight3D
var _t := 0.0

const ASPHALT := Color(0.2, 0.2, 0.21)
const ASPHALT_OLD := Color(0.27, 0.27, 0.26)
const DIRT := Color(0.36, 0.29, 0.2)
const GRAVEL := Color(0.38, 0.35, 0.3)
const RUST := Color(0.45, 0.22, 0.1)
const WOOD := Color(0.42, 0.3, 0.18)
const WOOD_OLD := Color(0.36, 0.32, 0.27)
const PLYWOOD := Color(0.62, 0.5, 0.33)
const LINE := Color(0.78, 0.76, 0.66)


func build() -> void:
	if Net.world_seed("site") != 0:
		_rng.seed = Net.world_seed("site")   # partie à deux : le même lieu chez les deux
	else:
		_rng.randomize()
	_body = StaticBody3D.new()
	_body.name = "SiteCollision"
	add_child(_body)
	match site_type:
		"superette": _build_superette()
		"aire": _build_rest_area()
		"camp": _build_camp()
		"motel": _build_motel()
	_merge_static()
	print("Lieu de départ : ", site_type)


func _process(delta: float) -> void:
	_t += delta
	for l in _neon:
		# lettres de néon fatiguées : coupures brèves et irrégulières
		var on := fmod(_t * 7.3 + l.get_instance_id() % 13, 11.0) > 0.6 and randf() > 0.02
		l.modulate.a = 1.0 if on else 0.12
	for f in _flicker:
		var on := randf() > 0.06 if fmod(_t, 4.0) < 3.2 else randf() > 0.5
		(f[0] as GeometryInstance3D).visible = on
		if f[1]:
			(f[1] as Light3D).visible = on
	if _fire:
		_fire.light_energy = 1.6 + 0.6 * sin(_t * 13.0) * sin(_t * 7.1) + randf() * 0.3


## Fusionne les centaines de petites pièces fixes en un maillage par matériau
## (quelques appels de rendu au lieu de centaines, important en VR). Les pièces
## qui clignotent restent à part.
func _merge_static() -> void:
	var keep := {}
	for f in _flicker:
		keep[f[0]] = true
	var tools := {}
	var parts: Array[Node] = []
	for mi in find_children("*", "MeshInstance3D", true, false):
		if keep.has(mi):
			continue
		var m: Material = (mi as MeshInstance3D).material_override
		if not tools.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[m] = st
		var xf := global_transform.affine_inverse() * (mi as Node3D).global_transform
		(tools[m] as SurfaceTool).append_from((mi as MeshInstance3D).mesh, 0, xf)
		parts.append(mi)
	var am := ArrayMesh.new()
	for m in tools:
		(tools[m] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, m)
	var merged := MeshInstance3D.new()
	merged.name = "SiteMesh"
	merged.mesh = am
	add_child(merged)
	for n in parts:
		n.get_parent().remove_child(n)
		n.free()


# --- Briques --------------------------------------------------------------------

func _mat(c: Color, emissive := 0.0, rough := 0.95) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c, emissive, rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = Color(c.r, c.g, c.b)
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]


## Boîte (taille, centre, rotation en degrés) ; `solid` ajoute une collision.
func box(size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, solid := false, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent else self).add_child(mi)
	if solid:
		_collider(size, mi.transform if parent == null else parent.transform * mi.transform)
	return mi


func cyl(r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, solid := false, sides := 10, r_top := -1.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent else self).add_child(mi)
	if solid:
		_collider(Vector3(r * 1.8, h, r * 1.8), mi.transform if parent == null else parent.transform * mi.transform)
	return mi


func blob(r: float, pos: Vector3, c: Color, squash := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 7
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi


func _collider(size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	_body.add_child(cs)


func label(text: String, pos: Vector3, c: Color, size := 64, rot := Vector3.ZERO, glow := false, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = c
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = rot
	l.shaded = not glow
	l.double_sided = false
	(parent if parent else self).add_child(l)
	return l


## Sol : dalle (asphalte, terre, gravier) avec l'entrée jusqu'à l'accotement.
func ground(x0: float, x1: float, z0: float, z1: float, c: Color) -> void:
	var size := Vector3(x1 - x0, 0.3, z1 - z0)
	var pos := Vector3((x0 + x1) * 0.5, -0.18, (z0 + z1) * 0.5)
	box(size, pos, c, Vector3.ZERO, true)


## Usure du sol : rapiéçages, fissures en zigzag, taches d'huile (teinte du sol).
func stains(x0: float, x1: float, z0: float, z1: float, n: int, c: Color) -> void:
	var base := c.lightened(0.12)
	for i in n:
		var p := Vector3(_rng.randf_range(x0, x1), -0.028 + (i % 7) * 0.0006, _rng.randf_range(z0, z1))
		var yaw := _rng.randf() * 180.0
		var r := _rng.randf()
		if r < 0.3:   # rapiéçage
			box(Vector3(_rng.randf_range(0.8, 2.6), 0.01, _rng.randf_range(0.6, 1.8)), p, base.darkened(_rng.randf_range(0.1, 0.3)), Vector3(0, yaw, 0))
		elif r < 0.75:   # fissure : trois segments en zigzag
			var q := p
			var a := deg_to_rad(yaw)
			for k in 3:
				var l := _rng.randf_range(0.5, 1.4)
				var d := Vector3(sin(a), 0, cos(a))
				box(Vector3(0.04, 0.01, l), q + d * l * 0.5, c.darkened(0.45), Vector3(0, rad_to_deg(a), 0))
				q += d * l
				a += _rng.randf_range(-0.9, 0.9)
		else:   # tache d'huile
			cyl(_rng.randf_range(0.25, 0.7), 0.01, p, c.darkened(0.35), Vector3(0, yaw, 0), false, 9)


## Touffes d'herbe folle (quelques brins fins, penchés) sur une zone.
func weeds(x0: float, x1: float, z0: float, z1: float, n: int) -> void:
	for i in n:
		var p := Vector3(_rng.randf_range(x0, x1), 0.0, _rng.randf_range(z0, z1))
		var g := Color(0.22 + _rng.randf() * 0.12, 0.3 + _rng.randf() * 0.1, 0.12)
		var hgt := _rng.randf_range(0.18, 0.45)
		for k in 3:
			var off := Vector3(_rng.randf_range(-0.07, 0.07), hgt * 0.5, _rng.randf_range(-0.07, 0.07))
			cyl(0.025, hgt, p + off, g, Vector3(_rng.randf_range(-25, 25), 0, _rng.randf_range(-25, 25)), false, 4, 0.003)


## Canettes et papiers.
func litter(x0: float, x1: float, z0: float, z1: float, n: int) -> void:
	var cols := [Color(0.75, 0.1, 0.1), Color(0.2, 0.4, 0.75), Color(0.8, 0.75, 0.2), Color(0.85, 0.85, 0.8), Color(0.2, 0.55, 0.2)]
	for i in n:
		var p := Vector3(_rng.randf_range(x0, x1), 0.03, _rng.randf_range(z0, z1))
		if _rng.randf() < 0.6:
			cyl(0.033, 0.12, p, cols[_rng.randi() % cols.size()], Vector3(90, _rng.randf() * 180, 0), false, 6)
		else:
			box(Vector3(0.21, 0.004, 0.15), p - Vector3(0, 0.02, 0), Color(0.8, 0.78, 0.7), Vector3(0, _rng.randf() * 180, 0))


func trash_bag(p: Vector3) -> void:
	blob(_rng.randf_range(0.3, 0.42), p + Vector3(0, 0.25, 0), Color(0.06, 0.06, 0.07), 0.75)


## Voiture épave (berline carrée), sur cales si `blocks`.
func wreck_car(p: Vector3, yaw: float, c: Color, blocks := false) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees.y = yaw
	add_child(n)
	var lift := 0.45 if blocks else 0.3
	box(Vector3(1.75, 0.55, 4.3), Vector3(0, lift + 0.28, 0), c, Vector3.ZERO, false, n)
	box(Vector3(1.55, 0.5, 2.2), Vector3(0, lift + 0.78, -0.2), c.darkened(0.1), Vector3.ZERO, false, n)
	box(Vector3(1.5, 0.42, 2.0), Vector3(0, lift + 0.8, -0.2), Color(0.12, 0.14, 0.16, 0.85), Vector3.ZERO, false, n)
	box(Vector3(0.6, 0.3, 0.8), Vector3(0.4, lift + 0.4, 1.3), RUST, Vector3.ZERO, false, n)       # rouille
	box(Vector3(0.5, 0.25, 0.6), Vector3(-0.6, lift + 0.35, -1.5), RUST, Vector3.ZERO, false, n)
	if blocks:
		for sx in [-0.7, 0.7]:
			for sz in [-1.3, 1.3]:
				box(Vector3(0.4, 0.4, 0.25), Vector3(sx, 0.2, sz), Color(0.55, 0.55, 0.53), Vector3.ZERO, false, n)
	else:
		for sx in [-0.85, 0.85]:
			for sz in [-1.35, 1.35]:
				cyl(0.32, 0.22, Vector3(sx, 0.32, sz), Color(0.08, 0.08, 0.08), Vector3(0, 0, 90), false, 10, -1.0, n)
	_collider(Vector3(1.8, 1.3, 4.4), n.transform * Transform3D(Basis(), Vector3(0, 0.65, 0)))


func barrel(p: Vector3, c: Color, tilt := Vector3.ZERO) -> MeshInstance3D:
	var b := cyl(0.29, 0.88, p + Vector3(0, 0.44, 0), c, tilt, true, 10)
	cyl(0.3, 0.04, p + Vector3(0, 0.25, 0), c.darkened(0.3), tilt, false, 10)
	cyl(0.3, 0.04, p + Vector3(0, 0.62, 0), c.darkened(0.3), tilt, false, 10)
	return b


func tire(p: Vector3, flat := true) -> void:
	if flat:
		cyl(0.36, 0.24, p + Vector3(0, 0.12, 0), Color(0.07, 0.07, 0.07), Vector3.ZERO, false, 10)
		cyl(0.18, 0.25, p + Vector3(0, 0.12, 0), Color(0.03, 0.03, 0.03), Vector3.ZERO, false, 8)
	else:
		cyl(0.36, 0.24, p + Vector3(0, 0.36, 0), Color(0.07, 0.07, 0.07), Vector3(0, 0, 90), false, 10)


func lamp_post(p: Vector3, broken: bool, tilt := 0.0) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees.z = tilt
	add_child(n)
	cyl(0.08, 6.0, Vector3(0, 3.0, 0), Color(0.35, 0.36, 0.36), Vector3.ZERO, false, 8, -1.0, n)
	box(Vector3(1.4, 0.08, 0.1), Vector3(0.6, 5.95, 0), Color(0.35, 0.36, 0.36), Vector3.ZERO, false, n)
	var head := box(Vector3(0.5, 0.15, 0.3), Vector3(1.2, 5.85, 0), Color(0.25, 0.25, 0.25), Vector3.ZERO, false, n)
	if not broken:
		var bulb := box(Vector3(0.4, 0.04, 0.22), Vector3(1.2, 5.76, 0), Color(1.0, 0.85, 0.55), Vector3.ZERO, false, n)
		bulb.material_override = _mat(Color(1.0, 0.8, 0.5), 2.5)
		_flicker.append([bulb, null])
	else:
		head.rotation_degrees.z = -35.0
	_collider(Vector3(0.3, 6.0, 0.3), n.transform * Transform3D(Basis(), Vector3(0, 3.0, 0)))


func plank_fence(a: Vector3, b: Vector3, gaps := 0.25) -> void:
	var d := b - a
	var fl := d.length()
	var n := int(fl / 2.2) + 1
	var yaw := rad_to_deg(atan2(d.x, d.z))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		var lean := _rng.randf_range(-8, 8)
		box(Vector3(0.12, 1.3, 0.12), p + Vector3(0, 0.6, 0), WOOD_OLD, Vector3(lean, 0, lean * 0.5))
	for k in 2:
		for i in n:
			if _rng.randf() < gaps:
				continue   # planche manquante
			var mid := a + d * ((i + 0.5) / n) + Vector3(0, 0.45 + k * 0.5, 0)
			box(Vector3(0.04, 0.16, fl / n), mid, WOOD_OLD.darkened(_rng.randf() * 0.2), Vector3(_rng.randf_range(-6, 6), yaw, 0))


## Pose la voiture du joueur (repère du lieu), tournée vers `dir`.
func place_car(p: Vector3, dir: Vector3) -> void:
	if car == null:
		return
	var z := (global_transform.basis * dir).normalized()
	z.y = 0.0
	z = z.normalized()
	var xf := Transform3D(Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z), global_transform * p + Vector3(0, 0.45, 0))
	car.global_transform = xf
	if car is RigidBody3D:
		var rb := car as RigidBody3D
		PhysicsServer3D.body_set_state(rb.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO


# --- Supérette désaffectée -----------------------------------------------------

func _build_superette() -> void:
	var hl := length * 0.5
	ground(-hl, hl * 0.82, -1.7, depth, ASPHALT_OLD)
	stains(-hl, hl * 0.8, 0.0, depth - 10.0, 45, ASPHALT_OLD)
	weeds(-hl, hl * 0.8, -1.5, depth, 60)
	litter(-hl, hl * 0.8, 0.0, depth - 9.0, 40)
	# places de parking effacées
	for i in 9:
		var x := -12.0 + i * 3.0
		if _rng.randf() < 0.8:
			box(Vector3(0.12, 0.01, 4.8), Vector3(x, -0.02, 11.0), Color(LINE, 0.55))
	# bâtiment
	var bz := depth - 9.5
	var bx0 := -hl + 4.0
	var bx1 := hl * 0.82 - 3.0
	var w := bx1 - bx0
	var cx := (bx0 + bx1) * 0.5
	var wall := Color(0.66, 0.62, 0.55)
	box(Vector3(w, 4.2, 8.5), Vector3(cx, 2.1, bz + 4.25), wall, Vector3.ZERO, true)
	box(Vector3(w + 0.3, 0.5, 8.8), Vector3(cx, 4.45, bz + 4.25), wall.darkened(0.15))   # acrotère
	box(Vector3(w, 0.9, 0.08), Vector3(cx, 0.45, bz - 0.03), wall.darkened(0.35))         # soubassement sale
	# coulures et taches sur la façade
	for i in 7:
		box(Vector3(_rng.randf_range(0.3, 1.0), _rng.randf_range(1.0, 2.6), 0.02), Vector3(_rng.randf_range(bx0 + 1, bx1 - 1), 3.0, bz - 0.06), wall.darkened(0.3))
	# vitrines condamnées (contreplaqué) et vitres cassées
	var door_x := cx + 1.0
	for i in 5:
		var x := bx0 + 2.0 + i * ((w - 4.0) / 4.0)
		if absf(x - door_x) < 1.6:
			continue
		box(Vector3(2.6, 2.2, 0.05), Vector3(x, 1.6, bz - 0.04), Color(0.08, 0.1, 0.12))
		if i % 2 == 0:
			box(Vector3(2.4, 2.0, 0.06), Vector3(x, 1.6, bz - 0.08), PLYWOOD, Vector3(0, 0, _rng.randf_range(-2, 2)))
			box(Vector3(2.3, 0.12, 0.08), Vector3(x, 1.0, bz - 0.12), PLYWOOD.darkened(0.2), Vector3(0, 0, 18))
		else:
			for k in 4:   # éclats de verre restés dans le cadre
				box(Vector3(0.5, 0.7, 0.02), Vector3(x - 0.8 + k * 0.5, 0.9 + (k % 2) * 1.0, bz - 0.09), Color(0.6, 0.75, 0.8, 0.5), Vector3(0, 0, k * 23))
	# porte métallique tordue
	box(Vector3(1.8, 2.4, 0.08), Vector3(door_x, 1.2, bz - 0.06), Color(0.4, 0.42, 0.42), Vector3(0, 8, 0))
	label("FERMÉ", Vector3(door_x, 1.9, bz - 0.12), Color(0.8, 0.1, 0.1), 40, Vector3(0, 180, 0))
	# enseigne délavée, lettres tombées
	box(Vector3(9.5, 1.1, 0.25), Vector3(cx, 3.5, bz - 0.15), Color(0.6, 0.18, 0.15))
	label("SUP  RETTE", Vector3(cx, 3.5, bz - 0.3), Color(0.95, 0.9, 0.75), 110, Vector3(0, 180, 0))
	box(Vector3(0.5, 0.6, 0.1), Vector3(cx + 2.4, 0.3, bz - 1.2), Color(0.95, 0.9, 0.75), Vector3(80, 20, 0))   # lettre tombée
	# tags
	label("PILS", Vector3(bx0 + 2.5, 2.4, bz - 0.1), Color(1.0, 0.35, 0.75), 120, Vector3(0, 180, -8))
	label("NO LIMIT", Vector3(bx1 - 2.0, 1.2, bz - 0.1), Color(0.3, 0.9, 0.4), 70, Vector3(0, 180, 5))
	# congélateur à glaçons, chariots, benne, sacs, palettes
	box(Vector3(1.6, 1.1, 0.8), Vector3(door_x + 2.4, 0.55, bz - 0.5), Color(0.85, 0.87, 0.88), Vector3.ZERO, true)
	label("GLACE", Vector3(door_x + 2.4, 0.75, bz - 0.92), Color(0.2, 0.4, 0.85), 40, Vector3(0, 180, 0))
	_cart(Vector3(-10.0, 0, 3.5), 40.0, false)
	_cart(Vector3(5.5, 0, 14.0), 110.0, true)
	box(Vector3(2.0, 1.4, 1.3), Vector3(bx1 + 1.6, 0.7, bz + 2.0), Color(0.15, 0.3, 0.18), Vector3(0, 90, 0), true)   # benne
	box(Vector3(2.1, 0.1, 1.4), Vector3(bx1 + 1.6, 1.5, bz + 1.7), Color(0.1, 0.2, 0.12), Vector3(-25, 90, 0))
	for i in 5:
		trash_bag(Vector3(bx1 + _rng.randf_range(0.5, 3.0), 0, bz + _rng.randf_range(-1.5, 0.5)))
	for i in 3:
		box(Vector3(1.2, 0.14, 0.8), Vector3(bx0 - 0.8, 0.07 + i * 0.15, bz + 1.0), WOOD, Vector3(0, _rng.randf_range(-10, 10), 0))
	lamp_post(Vector3(-hl + 2.0, 0, 2.0), false)
	lamp_post(Vector3(hl * 0.5, 0, 3.0), true, 9.0)
	place_car(Vector3(-3.0, 0, 7.5), Vector3(0.75, 0, -1.0))


func _cart(p: Vector3, yaw: float, fallen: bool) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees = Vector3(0, yaw, 90 if fallen else 0)
	if fallen:
		n.position.y += 0.35
	add_child(n)
	var metal := Color(0.7, 0.72, 0.72)
	for x in [-0.28, 0.28]:
		box(Vector3(0.03, 0.55, 0.9), Vector3(x, 0.75, 0), metal, Vector3.ZERO, false, n)
	box(Vector3(0.6, 0.03, 0.9), Vector3(0, 0.48, 0), metal, Vector3.ZERO, false, n)
	box(Vector3(0.6, 0.55, 0.03), Vector3(0, 0.75, 0.45), metal, Vector3.ZERO, false, n)
	box(Vector3(0.6, 0.55, 0.03), Vector3(0, 0.75, -0.45), metal, Vector3.ZERO, false, n)
	box(Vector3(0.6, 0.04, 0.04), Vector3(0, 1.08, -0.6), Color(0.8, 0.1, 0.1), Vector3.ZERO, false, n)
	for x in [-0.25, 0.25]:
		for z in [-0.4, 0.4]:
			cyl(0.05, 0.03, Vector3(x, 0.06, z), Color(0.1, 0.1, 0.1), Vector3(0, 0, 90), false, 6, -1.0, n)


# --- Aire de repos -------------------------------------------------------------

func _build_rest_area() -> void:
	var hl := length * 0.5
	ground(-hl, hl, -1.7, depth - 1.5, ASPHALT)
	box(Vector3(length - 6.0, 0.15, 0.3), Vector3(0, 0.0, depth - 1.6), Color(0.6, 0.6, 0.58))   # bordure
	stains(-hl + 2, hl - 2, 0.0, depth - 2.0, 30, ASPHALT)
	weeds(-hl, hl, -1.5, depth, 50)
	litter(-hl + 2, hl - 2, 0.0, depth, 45)
	# terre-plein entre la route et l'aire : herbe folle, bordures, deux buissons
	var ix0 := -hl + 12.0
	var ix1 := hl - 10.0
	box(Vector3(ix1 - ix0, 0.16, 1.8), Vector3((ix0 + ix1) * 0.5, -0.02, 1.6), Color(0.33, 0.42, 0.2), Vector3.ZERO, true)
	for dz in [0.66, 2.54]:
		box(Vector3(ix1 - ix0, 0.18, 0.15), Vector3((ix0 + ix1) * 0.5, -0.01, dz), Color(0.62, 0.62, 0.6))
	weeds(ix0, ix1, 0.9, 2.3, 30)
	for bx in [ix0 + 5.0, ix1 - 7.0]:
		blob(0.8, Vector3(bx, 0.35, 1.6), Color(0.2, 0.33, 0.16), 0.8)
		blob(0.55, Vector3(bx + 0.8, 0.3, 1.4), Color(0.24, 0.37, 0.18), 0.8)
	# panneau P bleu
	cyl(0.05, 2.6, Vector3(-hl + 1.5, 1.3, -1.0), Color(0.6, 0.62, 0.62), Vector3.ZERO, true, 6)
	box(Vector3(0.9, 0.9, 0.05), Vector3(-hl + 1.5, 2.4, -1.0), Color(0.1, 0.3, 0.7), Vector3(0, 90, 0))
	label("P", Vector3(-hl + 1.47, 2.4, -1.0), Color.WHITE, 90, Vector3(0, -90, 0))
	# table de pique-nique
	var tp := Vector3(8.0, 0, depth - 4.0)
	box(Vector3(2.0, 0.08, 0.8), tp + Vector3(0, 0.75, 0), WOOD, Vector3.ZERO, true)
	for dz in [-0.65, 0.65]:
		box(Vector3(2.0, 0.06, 0.28), tp + Vector3(0, 0.45, dz), WOOD_OLD)
	for dx in [-0.8, 0.8]:
		box(Vector3(0.08, 0.75, 1.6), tp + Vector3(dx, 0.37, 0), WOOD_OLD, Vector3(0, 0, 0))
	# poubelle qui déborde
	var bp := Vector3(4.0, 0, depth - 3.0)
	cyl(0.35, 0.95, bp + Vector3(0, 0.48, 0), Color(0.2, 0.35, 0.2), Vector3.ZERO, true, 10)
	for i in 4:
		trash_bag(bp + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.6)))
	blob(0.3, bp + Vector3(0, 1.0, 0), Color(0.06, 0.06, 0.07), 0.7)
	# toilettes chimiques
	var wc := Vector3(14.0, 0, depth - 3.0)
	box(Vector3(1.2, 2.3, 1.2), wc + Vector3(0, 1.15, 0), Color(0.15, 0.35, 0.65), Vector3(0, 5, 0), true)
	box(Vector3(1.3, 0.12, 1.3), wc + Vector3(0, 2.36, 0), Color(0.85, 0.85, 0.85), Vector3(0, 5, 0))
	box(Vector3(0.9, 1.9, 0.05), wc + Vector3(0.05, 1.05, -0.62), Color(0.12, 0.3, 0.55), Vector3(0, -20, 0))   # porte entrouverte
	label("HORS SERVICE", wc + Vector3(0, 1.6, -0.66), Color(0.9, 0.9, 0.9), 22, Vector3(0, 180, 0))
	# panneau d'information délavé
	var ip := Vector3(-8.0, 0, depth - 2.5)
	for dx in [-1.0, 1.0]:
		box(Vector3(0.1, 2.2, 0.1), ip + Vector3(dx, 1.1, 0), WOOD_OLD, Vector3.ZERO, true)
	box(Vector3(2.3, 1.2, 0.08), ip + Vector3(0, 1.6, 0), Color(0.55, 0.5, 0.42))
	label("AIRE DE REPOS", ip + Vector3(0, 1.95, -0.06), Color(0.25, 0.2, 0.15), 22, Vector3(0, 180, 0))
	label("PILS = LIBERTÉ", ip + Vector3(0.2, 1.45, -0.07), Color(1.0, 0.35, 0.75), 26, Vector3(0, 180, 6))
	lamp_post(Vector3(-2.0, 0, depth - 1.0), true, -6.0)
	wreck_car(Vector3(hl - 6.0, 0, 6.5), 95.0, Color(0.5, 0.48, 0.3))
	place_car(Vector3(-9.0, 0, 4.5), Vector3(1.0, 0, -0.15))


# --- Camp de caravanes ---------------------------------------------------------

func _build_camp() -> void:
	var hl := length * 0.5
	ground(-hl, hl, -1.7, depth, DIRT)
	box(Vector3(8.0, 0.02, 9.0), Vector3(-hl + 8.0, -0.02, 3.0), GRAVEL)   # entrée empierrée
	stains(-hl, hl, 0.0, depth, 30, DIRT)
	weeds(-hl, hl, -1.5, depth, 110)
	litter(-hl, hl, 2.0, depth, 70)
	_caravan(Vector3(-6.0, 0, depth - 8.0), 12.0, Color(0.85, 0.82, 0.7), Color(0.5, 0.35, 0.2), false)
	_caravan(Vector3(7.0, 0, depth - 6.5), -6.0, Color(0.78, 0.8, 0.76), Color(0.25, 0.4, 0.5), true)
	_caravan(Vector3(13.0, 0, 9.0), 80.0, Color(0.7, 0.66, 0.55), Color(0.55, 0.2, 0.15), false)
	_pickup(Vector3(-13.0, 0, depth - 12.0), 30.0)
	# pneus, fûts (un qui brûle), feu de camp, chaises, canapé
	for i in 6:
		tire(Vector3(-hl + 3.0 + (i % 2) * 0.2, i * 0.24, depth - 3.0), true)
	for i in 4:
		tire(Vector3(-hl + 5.0 + i * 0.8, 0, depth - 2.5 + _rng.randf()), _rng.randf() < 0.5)
	barrel(Vector3(2.0, 0, depth - 2.0), Color(0.2, 0.3, 0.55))
	barrel(Vector3(2.7, 0, depth - 1.6), RUST)
	barrel(Vector3(3.2, 0, depth - 2.6), Color(0.6, 0.15, 0.1), Vector3(80, 30, 0))
	var fire_p := Vector3(0.5, 0, 12.0)
	barrel(fire_p, RUST.darkened(0.2))
	var flame := cyl(0.24, 0.5, fire_p + Vector3(0, 1.1, 0), Color(1.0, 0.5, 0.1), Vector3.ZERO, false, 7, 0.02)
	flame.material_override = _mat(Color(1.0, 0.45, 0.08), 4.0)
	_fire = OmniLight3D.new()
	_fire.light_color = Color(1.0, 0.55, 0.2)
	_fire.omni_range = 6.0
	_fire.position = fire_p + Vector3(0, 1.3, 0)
	add_child(_fire)
	# cercle de pierres et bûches
	var camp := Vector3(-2.5, 0, 15.0)
	for i in 9:
		var a := TAU * i / 9.0
		box(Vector3(0.3, 0.2, 0.25), camp + Vector3(cos(a) * 0.9, 0.1, sin(a) * 0.9), Color(0.45, 0.44, 0.42), Vector3(0, rad_to_deg(a), 0))
	for i in 3:
		cyl(0.08, 0.9, camp + Vector3(0, 0.12, 0), Color(0.2, 0.15, 0.1), Vector3(90, i * 60, 0), false, 6)
	box(Vector3(1.2, 0.02, 1.2), camp + Vector3(0, 0.01, 0), Color(0.08, 0.07, 0.07))
	_chair(camp + Vector3(1.8, 0, 0.4), -100.0, Color(0.2, 0.45, 0.25))
	_chair(camp + Vector3(-1.5, 0, 1.2), 140.0, Color(0.7, 0.2, 0.15))
	_chair(camp + Vector3(0.2, 0, -1.9), 10.0, Color(0.2, 0.3, 0.6), true)
	var sofa := camp + Vector3(0.5, 0, 3.2)
	box(Vector3(2.0, 0.45, 0.9), sofa + Vector3(0, 0.25, 0), Color(0.45, 0.3, 0.22), Vector3(0, 175, 0), true)
	box(Vector3(2.0, 0.6, 0.25), sofa + Vector3(0, 0.75, 0.35), Color(0.4, 0.27, 0.2), Vector3(-10, 175, 0))
	box(Vector3(0.6, 0.12, 0.6), sofa + Vector3(-0.5, 0.54, 0), Color(0.5, 0.36, 0.26), Vector3(0, 160, 12))
	# fil à linge
	var cl0 := Vector3(-10.0, 0, depth - 4.0)
	var cl1 := Vector3(-4.0, 0, depth - 2.5)
	for p in [cl0, cl1]:
		cyl(0.05, 2.0, p + Vector3(0, 1.0, 0), WOOD_OLD, Vector3(0, 0, _rng.randf_range(-5, 5)), false, 6)
	var mid := (cl0 + cl1) * 0.5 + Vector3(0, 1.85, 0)
	var dl := cl1 - cl0
	box(Vector3(0.01, 0.01, dl.length()), mid, Color(0.8, 0.8, 0.8), Vector3(0, rad_to_deg(atan2(dl.x, dl.z)), 0))
	var cloth := [Color(0.85, 0.85, 0.82), Color(0.25, 0.3, 0.6), Color(0.6, 0.15, 0.15), Color(0.3, 0.45, 0.3)]
	for i in 4:
		box(Vector3(0.02, 0.6, 0.5), cl0 + dl * (0.2 + i * 0.2) + Vector3(0, 1.55, 0), cloth[i], Vector3(0, rad_to_deg(atan2(dl.x, dl.z)), 0))
	# clôture de planches de travers, groupe électrogène, niche, pancarte
	plank_fence(Vector3(-hl + 0.5, 0, depth - 0.5), Vector3(hl - 0.5, 0, depth - 0.5), 0.3)
	plank_fence(Vector3(hl - 0.5, 0, depth - 0.5), Vector3(hl - 0.5, 0, 14.0), 0.35)
	box(Vector3(1.0, 0.7, 0.6), Vector3(10.0, 0.35, depth - 2.2), Color(0.75, 0.6, 0.1), Vector3(0, 20, 0), true)
	box(Vector3(1.1, 1.0, 1.3), Vector3(-hl + 2.5, 0.5, 16.0), WOOD, Vector3(0, 30, 0), true)
	box(Vector3(1.2, 0.1, 1.5), Vector3(-hl + 2.5, 1.1, 16.0), WOOD_OLD, Vector3(0, 30, 15))
	cyl(0.04, 1.4, Vector3(-hl + 3.5, 0.7, 0.5), WOOD_OLD, Vector3.ZERO, false, 5)
	box(Vector3(1.2, 0.5, 0.04), Vector3(-hl + 3.5, 1.35, 0.5), PLYWOOD, Vector3(0, 0, -4))
	label("PROPRIÉTÉ PRIVÉE", Vector3(-hl + 3.5, 1.4, 0.47), Color(0.75, 0.1, 0.05), 22, Vector3(0, 180, -4))
	label("DÉGAGE", Vector3(-hl + 3.5, 1.24, 0.47), Color(0.75, 0.1, 0.05), 28, Vector3(0, 180, -4))
	place_car(Vector3(-hl + 8.0, 0, 7.0), Vector3(0.35, 0, -1.0))


## Caravane : caisse arrondie à deux tons, rouillée ; `on_blocks` = penchée sur cales.
func _caravan(p: Vector3, yaw: float, c: Color, stripe: Color, on_blocks: bool) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees = Vector3(0, yaw, -3.5 if on_blocks else 1.0)
	add_child(n)
	var l := 6.0
	box(Vector3(2.3, 2.1, l), Vector3(0, 1.45, 0), c, Vector3.ZERO, false, n)
	box(Vector3(2.0, 0.3, l - 0.6), Vector3(0, 2.6, 0), c.darkened(0.08), Vector3.ZERO, false, n)      # toit arrondi
	box(Vector3(2.32, 0.3, l + 0.01), Vector3(0, 1.2, 0), stripe, Vector3.ZERO, false, n)             # bande
	box(Vector3(2.0, 1.8, 0.4), Vector3(0, 1.35, l * 0.5 + 0.12), c.darkened(0.04), Vector3(-12, 0, 0), false, n)
	for z in [-1.8, 1.4]:   # fenêtres
		box(Vector3(2.34, 0.6, 1.1), Vector3(0, 1.85, z), Color(0.1, 0.12, 0.14), Vector3.ZERO, false, n)
	box(Vector3(2.35, 0.65, 0.55), Vector3(0, 1.85, -1.8), PLYWOOD, Vector3(0, 0, 0), false, n)       # vitre condamnée
	box(Vector3(0.05, 1.8, 0.75), Vector3(-1.17, 1.3, 0.2), c.darkened(0.2), Vector3.ZERO, false, n)  # porte
	for i in 6:   # rouille et coulures
		box(Vector3(2.36, _rng.randf_range(0.2, 0.7), _rng.randf_range(0.3, 1.0)), Vector3(0, _rng.randf_range(0.5, 2.2), _rng.randf_range(-2.7, 2.7)), RUST, Vector3.ZERO, false, n)
	# timon et roues (dont une crevée), ou cales
	box(Vector3(0.12, 0.12, 1.4), Vector3(0, 0.45, l * 0.5 + 0.7), Color(0.3, 0.3, 0.3), Vector3(0, 0, 0), false, n)
	if on_blocks:
		for z in [-2.0, 2.0]:
			for x in [-0.9, 0.9]:
				box(Vector3(0.4, 0.4, 0.4), Vector3(x, 0.2 + (0.15 if x > 0 else 0.0), z), Color(0.55, 0.55, 0.53), Vector3.ZERO, false, n)
	else:
		for x in [-1.2, 1.2]:
			cyl(0.34, 0.22, Vector3(x, 0.34 if x > 0 else 0.26, 0.0), Color(0.07, 0.07, 0.07), Vector3(0, 0, 90), false, 10, -1.0, n)
	# antenne parabolique sur une des caravanes
	if stripe.b > 0.4:
		cyl(0.4, 0.08, Vector3(0.4, 3.0, -1.5), Color(0.75, 0.75, 0.73), Vector3(60, 20, 0), false, 10, -1.0, n)
	_collider(Vector3(2.4, 2.8, l + 0.6), n.transform * Transform3D(Basis(), Vector3(0, 1.4, 0)))


func _pickup(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees.y = yaw
	add_child(n)
	var c := Color(0.35, 0.3, 0.25)
	box(Vector3(1.9, 0.7, 2.2), Vector3(0, 0.85, 1.5), RUST, Vector3.ZERO, false, n)          # capot
	box(Vector3(1.9, 1.0, 1.6), Vector3(0, 1.3, 0.0), c, Vector3.ZERO, false, n)              # cabine
	box(Vector3(1.8, 0.6, 1.4), Vector3(0, 1.5, 0.0), Color(0.12, 0.14, 0.16, 0.9), Vector3.ZERO, false, n)
	box(Vector3(1.9, 0.6, 2.3), Vector3(0, 0.85, -1.9), c.darkened(0.15), Vector3.ZERO, false, n)   # benne
	box(Vector3(1.6, 0.05, 1.0), Vector3(0, 1.5, 1.9), RUST.darkened(0.2), Vector3(-50, 0, 0), false, n)   # capot ouvert
	for x in [-0.75, 0.75]:
		for z in [-2.0, 1.6]:
			box(Vector3(0.4, 0.5, 0.3), Vector3(x, 0.25, z), Color(0.55, 0.55, 0.53), Vector3.ZERO, false, n)
	_collider(Vector3(2.0, 1.8, 5.6), n.transform * Transform3D(Basis(), Vector3(0, 0.9, 0)))


func _chair(p: Vector3, yaw: float, c: Color, fallen := false) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation_degrees = Vector3(80 if fallen else 0, yaw, 0)
	if fallen:
		n.position.y += 0.3
	add_child(n)
	box(Vector3(0.5, 0.04, 0.45), Vector3(0, 0.42, 0), c, Vector3.ZERO, false, n)
	box(Vector3(0.5, 0.5, 0.04), Vector3(0, 0.68, -0.22), c, Vector3(-12, 0, 0), false, n)
	for x in [-0.22, 0.22]:
		box(Vector3(0.02, 0.45, 0.02), Vector3(x, 0.21, 0.15), Color(0.6, 0.6, 0.6), Vector3(18, 0, 0), false, n)
		box(Vector3(0.02, 0.45, 0.02), Vector3(x, 0.21, -0.15), Color(0.6, 0.6, 0.6), Vector3(-18, 0, 0), false, n)


# --- Motel malfamé -------------------------------------------------------------

func _build_motel() -> void:
	var hl := length * 0.5
	ground(-hl, hl, -1.7, depth, ASPHALT_OLD)
	stains(-hl, hl, 0.0, depth - 9.0, 50, ASPHALT_OLD)
	weeds(-hl, hl, -1.5, depth, 55)
	litter(-hl, hl, 0.0, depth - 7.0, 50)
	var wall := Color(0.75, 0.62, 0.5)
	var trim := Color(0.35, 0.5, 0.48)
	# aile des chambres
	var bz := depth - 8.0
	var x0 := -hl + 3.0
	var x1 := hl - 9.0
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	box(Vector3(w, 3.3, 7.5), Vector3(cx, 1.65, bz + 3.75), wall, Vector3.ZERO, true)
	box(Vector3(w + 0.4, 0.35, 8.0), Vector3(cx, 3.47, bz + 3.75), trim)
	# auvent sur poteaux
	box(Vector3(w, 0.12, 2.2), Vector3(cx, 2.9, bz - 1.1), trim.darkened(0.1), Vector3(0, 0, 0.8))
	for i in int(w / 4.0) + 1:
		var px := x0 + 0.3 + i * 4.0
		cyl(0.07, 2.9, Vector3(px, 1.45, bz - 2.1), Color(0.6, 0.6, 0.58), Vector3(0, 0, 2.0 if i == 3 else 0.0), true, 6)
	box(Vector3(w, 0.15, 2.2), Vector3(cx, 0.05, bz - 1.1), Color(0.45, 0.44, 0.42))   # trottoir
	# chambres : porte numérotée, fenêtre et rideau, climatiseur, applique (certaines HS)
	var n_rooms := int(w / 3.6)
	var curtains := [Color(0.6, 0.15, 0.2), Color(0.75, 0.6, 0.2), Color(0.3, 0.35, 0.55), Color(0.5, 0.25, 0.4)]
	for i in n_rooms:
		var rx := x0 + 1.8 + i * 3.6
		var door_c: Color = [Color(0.5, 0.12, 0.1), Color(0.18, 0.3, 0.45)][i % 2]
		box(Vector3(0.95, 2.1, 0.06), Vector3(rx, 1.15, bz - 0.04), door_c, Vector3(0, 25 if i == 4 else 0, 0))
		label(str(i + 1), Vector3(rx, 1.75, bz - 0.09), Color(0.85, 0.75, 0.3), 36, Vector3(0, 180, 0))
		box(Vector3(1.3, 1.0, 0.04), Vector3(rx + 1.3, 1.5, bz - 0.03), Color(0.1, 0.12, 0.14))
		box(Vector3(0.6, 0.95, 0.05), Vector3(rx + 1.0, 1.5, bz - 0.05), curtains[i % curtains.size()])
		if i == 2:
			box(Vector3(1.3, 1.0, 0.06), Vector3(rx + 1.3, 1.5, bz - 0.07), PLYWOOD)   # vitre cassée condamnée
		box(Vector3(0.6, 0.4, 0.4), Vector3(rx + 1.3, 0.5, bz - 0.25), Color(0.7, 0.7, 0.68), Vector3.ZERO, true)
		var lamp := box(Vector3(0.18, 0.18, 0.12), Vector3(rx - 0.75, 2.35, bz - 0.08), Color(1.0, 0.85, 0.5))
		if i % 3 == 1:
			lamp.material_override = _mat(Color(0.3, 0.28, 0.24))
		else:
			lamp.material_override = _mat(Color(1.0, 0.82, 0.5), 3.0)
			if i % 3 == 2:
				_flicker.append([lamp, null])
	# accueil (petite aile vers la route)
	var ox := hl - 5.0
	box(Vector3(7.0, 3.1, 9.0), Vector3(ox, 1.55, bz - 1.0), wall.darkened(0.08), Vector3.ZERO, true)
	box(Vector3(7.4, 0.3, 9.4), Vector3(ox, 3.25, bz - 1.0), trim)
	box(Vector3(2.6, 1.4, 0.05), Vector3(ox - 0.5, 1.6, bz - 5.53), Color(0.1, 0.12, 0.14))
	var office := label("RÉCEPTION", Vector3(ox - 0.5, 2.65, bz - 5.6), Color(0.35, 0.9, 1.0), 44, Vector3(0, 180, 0), true)
	_neon.append(office)
	box(Vector3(0.9, 1.8, 0.7), Vector3(ox + 2.6, 0.9, bz - 6.0), Color(0.2, 0.25, 0.6), Vector3.ZERO, true)   # distributeur
	var vend := box(Vector3(0.7, 1.2, 0.02), Vector3(ox + 2.6, 1.1, bz - 6.36), Color(0.8, 0.9, 1.0))
	vend.material_override = _mat(Color(0.7, 0.85, 1.0), 1.5)
	box(Vector3(1.0, 1.3, 0.8), Vector3(ox - 3.0, 0.65, bz - 6.0), Color(0.85, 0.86, 0.87), Vector3.ZERO, true)   # machine à glaçons
	label("ICE", Vector3(ox - 3.0, 0.9, bz - 6.42), Color(0.2, 0.45, 0.9), 34, Vector3(0, 180, 0))
	# grande enseigne au bord de la route, néons fatigués
	var sp := Vector3(-hl + 2.0, 0, 0.5)
	cyl(0.15, 6.5, sp + Vector3(0, 3.25, 0), Color(0.45, 0.45, 0.45), Vector3.ZERO, true, 8)
	box(Vector3(4.6, 1.5, 0.35), sp + Vector3(0, 6.3, 0), Color(0.12, 0.1, 0.12), Vector3(0, 90, 0))
	var letters := "MOTEL"
	for i in letters.length():
		var l := label(letters[i], sp + Vector3(-0.2, 6.3, -1.6 + i * 0.8), Color(1.0, 0.15, 0.25), 120, Vector3(0, -90, 0), true)
		if i == 3:
			l.modulate = Color(0.3, 0.05, 0.08)   # lettre morte
		else:
			_neon.append(l)
	var vac := label("CHAMBRES LIBRES", sp + Vector3(-0.2, 5.25, 0), Color(1.0, 0.45, 0.8), 40, Vector3(0, -90, 0), true)
	_neon.append(vac)
	box(Vector3(3.6, 0.5, 0.3), sp + Vector3(0, 5.25, 0), Color(0.12, 0.1, 0.12), Vector3(0, 90, 0))
	# épave, sacs, matelas abandonné, places effacées
	wreck_car(Vector3(x0 + 9.0, 0, bz - 5.0), 178.0, Color(0.3, 0.35, 0.45))
	for i in 4:
		trash_bag(Vector3(x1 + _rng.randf_range(-1.0, 0.5), 0, bz + _rng.randf_range(-3.0, -2.2)))
	box(Vector3(1.4, 0.2, 1.9), Vector3(x0 + 2.0, 0.1, bz - 3.5), Color(0.75, 0.7, 0.6), Vector3(0, 30, 0))
	box(Vector3(0.6, 0.02, 0.5), Vector3(x0 + 2.2, 0.21, bz - 3.4), Color(0.55, 0.45, 0.3), Vector3(0, 60, 0))
	for i in n_rooms:
		if _rng.randf() < 0.7:
			box(Vector3(0.12, 0.01, 4.5), Vector3(x0 + 0.0 + i * 3.6, -0.02, bz - 5.0), Color(LINE, 0.5))
	lamp_post(Vector3(6.0, 0, 2.5), false, 4.0)
	place_car(Vector3(x0 + 13.0, 0, bz - 5.2), Vector3(0.5, 0, -1.0))
