class_name Smokable
extends VRPickable
## Cigarette ou joint qu'on allume au briquet et qu'on fume.
##
## - Allumer : en VR, le bout (côté opposé au filtre / au carton) tenu dans la flamme d'un
##   briquet allumé (Lighter) pendant ~0,4 s. Sans casque (une seule main), F en le tenant
##   l'allume avec le briquet de la voiture (s'il y en a un).
## - Fumer : allumé et tenu, le filtre porté à la bouche (même bouche que les pilules,
##   EdiblePickable.mouth_near ; en partie à deux, la bouche de l'autre joueur marche
##   aussi : on le fait fumer, c'est lui qui en ressent l'effet) : on tire dessus, la
##   braise rougit, le papier se
##   consume beaucoup plus vite ; en l'éloignant, on recrache un nuage de fumée. Sans
##   casque, F sur la cigarette allumée = une bouffée.
## - Allumé, il se consume aussi tout seul (lentement) et fume, même posé. Arrivé au
##   filtre, il s'éteint : il reste un mégot, qu'on ne peut plus rallumer.
##
## L'objet regarde vers +X : filtre / carton en -X, bout à brûler en +X (props/*.glb).

## Bouts du modèle (repère de l'objet) : fin du filtre (côté bouche), début et fin du
## papier, rayons du papier (côté filtre, côté bout).
@export var butt_x := -0.042
@export var paper_start := -0.018
@export var tip_x := 0.0425
@export var radius_start := 0.0038
@export var radius_tip := 0.0038
@export var filter_color := Color(0.82, 0.55, 0.28)
@export var paper_color := Color(0.95, 0.94, 0.9)
## Secondes de bouffées pour le fumer en entier, et secondes pour qu'il se consume seul.
@export var puff_time := 10.0
@export var idle_time := 240.0
## Papier qui reste quand il s'éteint (m).
@export var stub := 0.004
## « cigarette » : calme le manque ; « joint » : calme le manque et défonce
## (PillAddiction.smoke).
@export_enum("cigarette", "joint") var kind := "cigarette"

const MOUTH_RADIUS := 0.085
const FLAME_RADIUS := 0.03
const LIGHT_DELAY := 0.4

var lit := false
var burnt_out := false
var burnt := 0.0           # longueur de papier consumée (m)
var puffs := 0

var _built_smoke := false
var _paper: MeshInstance3D
var _ember: MeshInstance3D
var _ember_mat: StandardMaterial3D
var _ash: MeshInstance3D
var _smoke: CPUParticles3D
var _exhale: CPUParticles3D
var _sizzle: AudioStreamPlayer3D
var _flame_t := 0.0
var _mouth_t := 0.0        # temps passé à la bouche (bouffée en cours)
var _auto_puff := 0.0      # bouffée simulée (F sans casque)
var _auto_puff_remote := false   # ... demandée par l'autre joueur (partie à deux)
var _puff_head: Node3D     # tête de celui qui tire dessus (souffle recraché par sa bouche)
var _t := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("smokables")


func paper_length() -> float:
	return tip_x - paper_start


## Position monde du bout (là où brûle la braise) et du filtre (côté bouche).
func tip_position() -> Vector3:
	return item.global_transform * Vector3(tip_x - burnt, 0, 0)


func butt_position() -> Vector3:
	return item.global_transform * Vector3(butt_x, 0, 0)


## F / A / X en le tenant : l'allume avec le briquet de la voiture, ou tire une bouffée.
func toggle() -> void:
	if not is_grabbed() or burnt_out:
		return
	if not lit:
		var lighter := get_tree().get_first_node_in_group("lighters")
		if lighter:
			if lighter.has_method("play_click"):
				lighter.call("play_click")
			light()
		return
	_auto_puff = 1.4
	_auto_puff_remote = Net.applying_remote


func light() -> void:
	if lit or burnt_out:
		return
	lit = true
	_build_burning()
	_update_shape()


func extinguish() -> void:
	lit = false
	if _ember:
		_ember.visible = false
	if _smoke:
		_smoke.emitting = false
	if _sizzle:
		_sizzle.stop()


func _process(delta: float) -> void:
	if burnt_out or item == null:
		return
	_t += delta
	if not lit:
		_check_flame(delta)
		return
	# bouffée : le filtre à la bouche, en le tenant (ou F sans casque)
	var at_mouth := false
	var remote := Net.is_online() and Net.held_by_remote(self)   # l'autre joueur fume
	if is_grabbed():
		var m := EdiblePickable.mouth_near(get_tree(), butt_position(), MOUTH_RADIUS)
		if not m.is_empty():
			at_mouth = true
			remote = not m[2]   # à la bouche de l'autre joueur : c'est lui qui fume
			_puff_head = m[1]
	if _auto_puff > 0.0:
		_auto_puff -= delta
		at_mouth = true
		remote = remote or _auto_puff_remote
		if _auto_puff <= 0.0:
			_auto_puff = 0.0
	var burn_len := paper_length() - stub
	var rate := burn_len / idle_time + (burn_len / puff_time if at_mouth else 0.0)
	burnt = minf(burnt + rate * delta, burn_len)
	if at_mouth:
		_mouth_t += delta
		var add := get_tree().get_first_node_in_group(PillAddiction.GROUP)
		if add and not remote:
			add.call("smoke", kind, delta / puff_time)
		if _sizzle and not _sizzle.playing:
			_sizzle.play()
	else:
		if _mouth_t > 0.35:
			_exhale_puff(_mouth_t)
		_mouth_t = 0.0
		if _sizzle and _sizzle.playing:
			_sizzle.stop()
	# braise : rougit pendant la bouffée, palpite sinon
	var glow := 3.5 if at_mouth else 1.2 + 0.3 * sin(_t * 3.0)
	if _ember_mat:
		_ember_mat.emission_energy_multiplier = glow
	_update_shape()
	if burnt >= burn_len - 0.0001:
		extinguish()
		burnt_out = true
		if _mouth_t > 0.35:
			_exhale_puff(_mouth_t)
		print("%s fumé jusqu'au filtre (%d bouffées)" % [item.name, puffs])


## Bout tenu dans la flamme d'un briquet allumé : s'allume au bout de LIGHT_DELAY s.
func _check_flame(delta: float) -> void:
	var near := false
	for l in get_tree().get_nodes_in_group("lighters"):
		if l.get("lit") and l.has_method("flame_position"):
			if (l.call("flame_position") as Vector3).distance_to(tip_position()) < FLAME_RADIUS:
				near = true
				break
	_flame_t = _flame_t + delta if near else 0.0
	if _flame_t >= LIGHT_DELAY:
		light()


func _exhale_puff(strength: float) -> void:
	puffs += 1
	var mouth = EdiblePickable.mouth_position(get_tree(), self)
	var cam: Node3D = Net.camera_for(self) if Net.is_online() else get_viewport().get_camera_3d()
	if _puff_head and is_instance_valid(_puff_head) and _auto_puff <= 0.0:
		cam = _puff_head
		mouth = cam.global_transform * EdiblePickable.MOUTH_OFFSET
	if mouth == null or cam == null or _exhale == null:
		return
	# un peu devant la bouche : le nuage ne bouche pas toute la vue
	_exhale.global_position = mouth - cam.global_basis.z * 0.12
	_exhale.direction = -cam.global_basis.z + Vector3(0, 0.15, 0)
	_exhale.amount = clampi(int(12 + strength * 14.0), 12, 40)
	_exhale.restart()
	_exhale.emitting = true


# --- Visuel de la cigarette allumée -------------------------------------------------

## Remplace le modèle par un filtre fixe + un papier qui raccourcit, une braise et un
## peu de cendre au bout, la fumée qui monte du bout et le souffle recraché.
func _build_burning() -> void:
	if _built_smoke:
		return
	_built_smoke = true
	var model := item.get_node_or_null("Model") as Node3D
	if model:
		model.visible = false
	var root := Node3D.new()
	root.name = "Burning"
	item.add_child(root)
	var filter := _cyl(paper_start - butt_x, radius_start, radius_start, filter_color, false)
	filter.position.x = (butt_x + paper_start) * 0.5
	root.add_child(filter)
	_paper = _cyl(1.0, radius_start, radius_tip, paper_color, false)
	root.add_child(_paper)
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(1.0, 0.35, 0.08)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.3, 0.05)
	_ember_mat.emission_energy_multiplier = 1.2
	_ember = _cyl(0.003, radius_tip * 0.95, radius_tip * 0.7, Color.WHITE, false)
	_ember.material_override = _ember_mat
	root.add_child(_ember)
	_ash = _cyl(0.002, radius_tip * 0.7, radius_tip * 0.4, Color(0.45, 0.44, 0.42), false)
	root.add_child(_ash)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.set_meta("_vr_outline", true)
	refresh_meshes()
	# fumée du bout : fins flocons gris qui montent et s'étalent
	_smoke = _make_smoke(14, 2.2, 0.012, 0.05)
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.03
	_smoke.initial_velocity_max = 0.07
	_smoke.gravity = Vector3(0, 0.05, 0)
	item.add_child(_smoke)
	_smoke.emitting = true
	# souffle recraché par la bouche (gerbe ponctuelle)
	_exhale = _make_smoke(24, 2.6, 0.03, 0.16)
	_exhale.one_shot = true
	_exhale.explosiveness = 0.75
	_exhale.spread = 22.0
	_exhale.initial_velocity_min = 0.25
	_exhale.initial_velocity_max = 0.55
	_exhale.damping_min = 0.4
	_exhale.damping_max = 0.6
	_exhale.gravity = Vector3(0, 0.04, 0)
	_exhale.emitting = false
	get_tree().current_scene.add_child(_exhale)
	_sizzle = AudioStreamPlayer3D.new()
	_sizzle.stream = _make_sizzle()
	_sizzle.unit_size = 1.0
	_sizzle.volume_db = -14.0
	item.add_child(_sizzle)


func _update_shape() -> void:
	if _paper == null:
		return
	var ln := maxf(paper_length() - burnt, 0.0005)
	var end := tip_x - burnt
	_paper.scale = Vector3(1, ln, 1)
	_paper.position = Vector3(paper_start + ln * 0.5, 0, 0)
	var r_end := lerpf(radius_start, radius_tip, ln / paper_length())
	(_paper.mesh as CylinderMesh).top_radius = r_end
	_ember.position = Vector3(end + 0.0015, 0, 0)
	_ember.visible = lit
	_ash.position = Vector3(end + 0.0035, 0, 0)
	_ash.visible = burnt > 0.002
	if _smoke:
		_smoke.position = Vector3(end + 0.003, 0, 0)


## Cylindre couché le long de X (CylinderMesh : axe Y), longueur `length`.
func _cyl(length: float, r0: float, r1: float, c: Color, _shaded := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = length
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	mi.material_override = m
	mi.rotation = Vector3(0, 0, -PI * 0.5)   # +Y du cylindre -> +X de l'objet
	return mi


func _make_smoke(amount: int, life: float, size0: float, size1: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size1   # taille dans le maillage (l'échelle seule ne suffit pas ici)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# (couleur par particule non fiable en rendu Compatibility : particules noires)
	m.albedo_color = Color(0.84, 0.84, 0.86, 0.32)
	m.albedo_texture = _puff_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	# grossit en montant puis se dissipe (rétrécit) en fin de vie
	var curve := Curve.new()
	curve.add_point(Vector2(0, size0 / size1))
	curve.add_point(Vector2(0.75, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.3
	p.scale_amount_curve = curve
	p.angle_min = 0.0
	p.angle_max = 360.0
	return p


static var _tex: Texture2D

## Petite tache ronde et floue (texture de fumée).
static func _puff_texture() -> Texture2D:
	if _tex:
		return _tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Grésillement du tabac qui brûle pendant qu'on tire (bruit doux en boucle).
static func _make_sizzle() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var crackle := rng.randf_range(-1.0, 1.0) * (1.0 if rng.randf() < 0.02 else 0.18)
		lp += (crackle - lp) * 0.35
		data.encode_s16(i * 2, int(clampf(lp, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
