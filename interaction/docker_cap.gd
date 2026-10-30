class_name DockerCap
extends VRPickable
## Bonnet de docker (calotte en velours côtelé, revers roulé, étiquette, patte et
## boucle de serrage à l'arrière) qu'on met sur la tête d'un joueur.
##
## - Le mettre : en VR, le lâcher au-dessus d'une tête (la sienne ou, en partie à deux,
##   celle de l'autre joueur) ; sans casque, F en le tenant : sur sa propre tête.
## - L'enlever : l'attraper sur la tête (n'importe lequel des deux joueurs).
## - Porté, il suit la tête à chaque image. Chez celui qui le porte, il est caché à sa
##   propre caméra (il passerait devant les yeux) mais reste visible dans les rétros.
## - Partie à deux : seule la machine de la main qui le lâche décide sur quelle tête il
##   va (comme pour la bouche, EdiblePickable.mouth_near) et prévient l'autre
##   (Net.wear -> NetSession.on_wear). Porté, il est rangé directement sous la voiture,
##   au même chemin chez les deux joueurs (les saisies de l'autre le retrouvent) ; ses
##   places ne sont pas envoyées avec les objets en vrac.
##
## Le modèle est construit ici (formes simples) : repère du bonnet = centre du bas du
## revers, +Y vers le haut, avant en -Z.

## Meta posée sur l'objet porté (NetSession ne l'envoie pas avec les objets en vrac).
const WORN_META := "worn_cap"
## Couche de rendu du bonnet porté par le joueur local : cachée à sa caméra.
const WORN_LAYER := 1 << 18

## Place du bonnet sur la tête (repère des yeux : -Z devant) : basculé vers la nuque,
## l'avant remonte au-dessus des sourcils.
@export var wear_offset := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(14.0)), Vector3(0.0, 0.042, 0.03))
## Distance (m) entre le bonnet lâché et sa place sur une tête pour qu'il s'y mette.
@export var wear_radius := 0.17
@export var fabric_color := Color(0.80, 0.76, 0.65)

## Rayon intérieur (sur les côtés), hauteur du revers et hauteur de la calotte (m). Le
## bonnet est ovale comme une tête : plus long d'avant en arrière (DEPTH).
const RADIUS := 0.1
const DEPTH := 1.14
const CUFF_H := 0.036
const DOME_H := 0.068
const PANELS := 6

## Tête qui le porte (caméra du joueur local ou yeux de l'avatar de l'autre), ou null.
var head: Node3D
## Porté sur la place du conducteur (vrai) ou du copilote : même sens chez les deux.
var worn_driver_seat := false


func _ready() -> void:
	item = get_parent() as RigidBody3D
	var model := item.get_node_or_null("Model") as Node3D
	if model and model.get_child_count() == 0:
		var mi := MeshInstance3D.new()
		mi.name = "Cap"
		mi.mesh = build_mesh(fabric_color)
		model.add_child(mi)
	process_priority = 100   # après la caméra et l'avatar de l'autre joueur
	super._ready()


func is_worn() -> bool:
	return head != null


# --- Mettre / enlever ------------------------------------------------------------------

func _on_grab_begin(hand: Node3D) -> void:
	if is_worn():
		_take_off()
	super._on_grab_begin(hand)


func _on_grab_end(hand: Node3D) -> void:
	if is_worn():
		_active_hand = null   # mis sur une tête pendant qu'on le tenait (voir wear)
		return
	if hand != _active_hand or _grab_hands.size() > 0:
		super._on_grab_end(hand)
		return
	# seule la machine de la main qui le lâche choisit la tête (l'autre rejoue)
	if not Net.applying_remote:
		# là où la main le tient (l'objet tenu peut traîner derrière elle, bloqué par
		# l'intérieur de la voiture)
		var seat = _head_near((_hand_xf(hand) * _offset).origin)
		if seat == null:
			seat = _head_near(item.global_position)
		if seat != null:
			_active_hand = null
			put_on(seat)
			return
	super._on_grab_end(hand)


## F / A / X en le tenant : sur sa propre tête.
func toggle() -> void:
	if Net.applying_remote or not is_grabbed():
		return   # chez l'autre joueur, c'est Net.wear qui le met
	put_on(Net.is_driver())


## Le met sur la tête du conducteur (`driver_seat` vrai) ou du copilote, ici et chez
## l'autre joueur.
func put_on(driver_seat: bool) -> void:
	Net.wear(item, driver_seat)
	wear(driver_seat)


## Le met sur la tête de la place donnée (appelé chez les deux joueurs).
func wear(driver_seat: bool) -> void:
	var h := _head_for(driver_seat)
	if h == null:
		return
	head = h
	worn_driver_seat = driver_seat
	# lâché par toutes les mains (sans repasser par les rangements)
	for hd in _grab_hands.duplicate():
		release(hd)
	for grp in [VRHandInteractor.GROUP, MouseHand.GROUP, NetRemoteHand.GROUP]:
		for hn in get_tree().get_nodes_in_group(grp):
			if hn.get("held") == self:
				hn.set("held", null)
	_active_hand = null
	var zone := item.get_parent() as StorageZone
	if zone:
		zone.on_item_taken(item)
	ItemPhysics.stop(item)
	for m in ["rest_xf", "free_timer", "net_remote_until", "net_xf", "net_local_until"]:
		if item.has_meta(m):
			item.remove_meta(m)
	item.set_meta(WORN_META, true)
	# rangé sous la voiture : même chemin chez les deux joueurs, et aucun rangement
	# (CarStorage, StorageZone) ne le fait plus glisser
	var car := get_tree().get_first_node_in_group(SUV4x4.GROUP) as Node3D
	if car and item.get_parent() != car:
		item.reparent(car, true)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.top_level = true
	CarStorage.pin_body(item)
	_set_hidden_from_me(head == get_viewport().get_camera_3d())
	_follow_head()
	print("Bonnet mis sur la tête du %s" % ("conducteur" if driver_seat else "copilote"))


func _take_off() -> void:
	head = null
	item.remove_meta(WORN_META)
	_set_hidden_from_me(false)


func _process(_delta: float) -> void:
	if head == null:
		return
	if not is_instance_valid(head) or not head.is_inside_tree():
		# l'autre joueur est parti : le bonnet tombe dans la voiture
		_take_off()
		var storage := _nearest_storage()
		if storage:
			storage.receive(item, Vector3.ZERO)
		return
	_follow_head()


func _follow_head() -> void:
	item.global_transform = head.global_transform.orthonormalized() * wear_offset


## Tête du joueur assis à cette place : la nôtre (caméra) ou celle de l'autre joueur.
func _head_for(driver_seat: bool) -> Node3D:
	if driver_seat == Net.is_driver():
		return get_viewport().get_camera_3d()
	return Net.other_head() if Net.is_online() else null


## Place (vrai = conducteur) de la tête au-dessus de laquelle est `point`, ou null.
func _head_near(point: Vector3) -> Variant:
	var best = null
	var best_d := wear_radius
	for seat in [Net.is_driver(), not Net.is_driver()]:
		var h := _head_for(seat)
		if h == null or not is_instance_valid(h):
			continue
		var xf := h.global_transform.orthonormalized()
		if (xf.affine_inverse() * point).y < 0.0:
			continue   # sous les yeux : pas sur la tête
		var d := (xf * wear_offset).origin.distance_to(point)
		if d < best_d:
			best_d = d
			best = seat
	return best


## Porté par le joueur local : sur une couche que sa caméra ne montre pas (les rétros,
## si). Les contours de surlignage, créés plus tard, suivent (_ensure_built).
func _set_hidden_from_me(hide: bool) -> void:
	for g in item.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = WORN_LAYER if hide else 1
	if hide:
		var cam := get_viewport().get_camera_3d()
		if cam:
			cam.cull_mask &= ~WORN_LAYER


func _ensure_built() -> void:
	var was_built := _built
	super._ensure_built()
	if not was_built and head != null and head == get_viewport().get_camera_3d():
		_set_hidden_from_me(true)


# --- Modèle ----------------------------------------------------------------------------

static var _rib_tex: Texture2D
static var _label_tex: Texture2D


## Bonnet complet : calotte et revers en velours côtelé (6 pans), œillets, étiquette
## tissée, patte de serrage et boucle à l'arrière.
static func build_mesh(color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var rc := RADIUS + 0.006   # revers (roulé par-dessus)
	# --- velours : revers puis calotte, profils tournés autour de Y
	var cuff := PackedVector2Array([
		Vector2(RADIUS - 0.002, 0.006), Vector2(RADIUS + 0.001, 0.0), Vector2(rc + 0.003, 0.002),
		Vector2(rc + 0.005, CUFF_H * 0.5), Vector2(rc + 0.004, CUFF_H - 0.003),
		Vector2(rc, CUFF_H + 0.001), Vector2(RADIUS, CUFF_H - 0.001)])
	var dome := PackedVector2Array()
	for i in 13:
		var phi := PI * 0.5 * i / 12.0
		var r := RADIUS * cos(phi) * (1.0 + 0.05 * sin(phi * 2.0))
		dome.append(Vector2(r, CUFF_H + DOME_H * sin(phi)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(st, cuff, 0.0, 0.3)
	_lathe(st, dome, 0.3, 1.0)
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = color
	fabric.albedo_texture = _ribs()
	fabric.roughness = 1.0
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED   # on voit l'intérieur
	st.set_material(fabric)
	st.commit(mesh)
	# --- œillets brodés : un petit anneau au milieu de chaque pan, trou sombre au centre
	var rings := SurfaceTool.new()
	rings.begin(Mesh.PRIMITIVE_TRIANGLES)
	var holes := SurfaceTool.new()
	holes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.0022
	torus.outer_radius = 0.0042
	torus.rings = 12
	torus.ring_segments = 6
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0024
	disc.bottom_radius = 0.0024
	disc.height = 0.0006
	disc.radial_segments = 10
	disc.rings = 1
	for k in PANELS:
		var a := TAU * (k + 0.5) / PANELS
		var phi := 0.62
		var r := RADIUS * cos(phi) * (1.0 + 0.05 * sin(phi * 2.0))
		var p := _ring_point(r, CUFF_H + DOME_H * sin(phi), a)
		var n := Vector3(sin(a) * DOME_H * cos(phi), RADIUS * sin(phi), -cos(a) * DOME_H * cos(phi)).normalized()
		var b := _basis_y(n)
		rings.append_from(torus, 0, Transform3D(b, p + n * 0.0006))
		holes.append_from(disc, 0, Transform3D(b, p + n * 0.0004))
	rings.set_material(fabric)
	rings.commit(mesh)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.17, 0.15, 0.12)
	dark.roughness = 1.0
	holes.set_material(dark)
	holes.commit(mesh)
	# --- étiquette tissée sur le revers, côté gauche vers l'arrière
	var label := SurfaceTool.new()
	label.begin(Mesh.PRIMITIVE_TRIANGLES)
	var la := deg_to_rad(232.0)
	var lr := rc + 0.0058
	var lw := 0.052 / lr   # demi-angle : 26 mm de part et d'autre
	# (de l'angle le plus grand au plus petit : le texte se lit de gauche à droite)
	_band(label, lr, la + lw * 0.5, la - lw * 0.5, CUFF_H * 0.5 - 0.012, CUFF_H * 0.5 + 0.012, 6)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = _label()
	lm.roughness = 0.9
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	label.set_material(lm)
	label.commit(mesh)
	# --- arrière : patte de serrage sous le revers, petite patte en cuir, boucle
	var strap := SurfaceTool.new()
	strap.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(strap, RADIUS + 0.0015, PI - 0.42, PI + 0.42, -0.006, 0.01, 10)
	var leather := BoxMesh.new()
	leather.size = Vector3(0.009, 0.03, 0.003)
	var ta := PI - 0.2
	strap.append_from(leather, 0, Transform3D(_basis_y(Vector3.UP).rotated(Vector3.UP, -ta), _ring_point(rc + 0.006, CUFF_H * 0.45, ta)))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.3, 0.12, 0.1)
	sm.roughness = 0.75
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	strap.set_material(sm)
	strap.commit(mesh)
	var buckle := SurfaceTool.new()
	buckle.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bx := BoxMesh.new()
	bx.size = Vector3(0.018, 0.013, 0.003)
	var ba := PI + 0.24
	buckle.append_from(bx, 0, Transform3D(Basis(Vector3.UP, -ba), _ring_point(RADIUS + 0.004, 0.002, ba)))
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.62, 0.4)
	metal.metallic = 0.8
	metal.roughness = 0.35
	buckle.set_material(metal)
	buckle.commit(mesh)
	return mesh


## Point à la distance `r` de l'axe, à la hauteur `y`, à l'angle `a` (0 = devant, -Z ;
## PI/2 = à droite, +X).
static func _ring_point(r: float, y: float, a: float) -> Vector3:
	return Vector3(r * sin(a), y, -r * cos(a) * DEPTH)


static func _basis_y(n: Vector3) -> Basis:
	var x := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, n, x.cross(n))


## Surface de révolution du profil (r, y), v de `v0` à `v1` le long du profil. Les côtes
## du velours suivent les méridiens (texture répétée une fois par pan).
static func _lathe(st: SurfaceTool, profile: PackedVector2Array, v0: float, v1: float) -> void:
	var segs := 40
	var n := profile.size()
	var normals: Array[Vector2] = []
	var lens := [0.0]
	for i in n:
		var t := Vector2.ZERO
		if i > 0:
			t += (profile[i] - profile[i - 1]).normalized()
		if i < n - 1:
			t += (profile[i + 1] - profile[i]).normalized()
		normals.append(Vector2(t.y, -t.x).normalized())
		if i > 0:
			lens.append(lens[-1] + profile[i].distance_to(profile[i - 1]))
	for i in n - 1:
		for j in segs:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a := TAU * float(c[1]) / segs
				var p: Vector2 = profile[c[0]]
				var nn: Vector2 = normals[c[0]]
				quad.append([_ring_point(p.x, p.y, a), Vector3(nn.x * sin(a), nn.y, -nn.x * cos(a)),
						Vector2(float(c[1]) / segs * PANELS, lerpf(v0, v1, lens[c[0]] / lens[-1]))])
			for k in [0, 2, 1, 0, 3, 2]:   # sens des faces avant de Godot (éclairage)
				st.set_normal(quad[k][1])
				st.set_uv(quad[k][2])
				st.add_vertex(quad[k][0])


## Bande courbe (cylindre partiel de rayon `r`) entre deux angles et deux hauteurs ;
## u de 0 à 1 le long de la bande, v de haut en bas.
static func _band(st: SurfaceTool, r: float, a0: float, a1: float, y0: float, y1: float, segs: int) -> void:
	for j in segs:
		var quad := []
		for c in [[j, y1], [j + 1, y1], [j + 1, y0], [j, y0]]:
			var u := float(c[0]) / segs
			var a := lerpf(a0, a1, u)
			quad.append([_ring_point(r, c[1], a), Vector3(sin(a), 0, -cos(a)), Vector2(u, 0.0 if c[1] == y1 else 1.0)])
		for k in [0, 2, 1, 0, 3, 2]:   # sens des faces avant de Godot (éclairage)
			st.set_normal(quad[k][1])
			st.set_uv(quad[k][2])
			st.add_vertex(quad[k][0])


## Côtes du velours (un pan par répétition) avec la couture du pan sur le bord.
static func _ribs() -> Texture2D:
	if _rib_tex:
		return _rib_tex
	var w := 112
	var img := Image.create(w, 4, false, Image.FORMAT_RGB8)
	var rib := [0.8, 0.97, 1.0, 0.88]
	for x in w:
		var v: float = rib[x % 4]
		if x < 2 or x >= w - 2:
			v = 0.62   # couture entre deux pans
		for y in 4:
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_rib_tex = ImageTexture.create_from_image(img)
	return _rib_tex


## Étiquette tissée : fond bleu marine, liseré crème et « NFP » en lettres carrées.
static func _label() -> Texture2D:
	if _label_tex:
		return _label_tex
	var w := 52
	var h := 24
	var navy := Color(0.1, 0.12, 0.24)
	var cream := Color(0.88, 0.85, 0.74)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(navy)
	for x in range(2, w - 2):
		img.set_pixel(x, 2, cream)
		img.set_pixel(x, h - 3, cream)
	for y in range(2, h - 2):
		img.set_pixel(2, y, cream)
		img.set_pixel(w - 3, y, cream)
	var glyphs := {
		"N": ["X...X", "XX..X", "X.X.X", "X..XX", "X...X"],
		"F": ["XXXXX", "X....", "XXXX.", "X....", "X...."],
		"P": ["XXXX.", "X...X", "XXXX.", "X....", "X...."],
	}
	var px := 10
	for ch in "NFP":
		var g: Array = glyphs[ch]
		for gy in 5:
			for gx in 5:
				if (g[gy] as String)[gx] == "X":
					for dy in 2:
						for dx in 2:
							img.set_pixel(px + gx * 2 + dx, 7 + gy * 2 + dy, cream)
		px += 12
	img.generate_mipmaps()
	_label_tex = ImageTexture.create_from_image(img)
	return _label_tex
