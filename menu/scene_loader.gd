extends Node
## Changement de scène avec écran de chargement (autoload SceneLoader), au lieu de
## l'image figée puis grise pendant que Godot charge et prépare la nouvelle scène.
##
## 1. Un voile sombre « CHARGEMENT » avec une barre de progression apparaît en fondu
##    devant la caméra (casque ou écran : c'est un objet 3D accroché à la caméra).
## 2. La scène est chargée dans un fil d'exécution à part : l'ancienne scène continue
##    de tourner (le menu reste animé, la tête suit dans le casque).
## 3. On change de scène derrière le voile : la dernière image affichée pendant
##    l'instanciation est le voile, pas une image figée du jeu.
## 4. Le voile reste devant la nouvelle scène le temps qu'elle se stabilise (premiers
##    tronçons de route, compilation des shaders), puis s'efface en fondu.
## preload_scene() lance le chargement en avance (le menu précharge le jeu).

signal loading_started(path: String)
signal loading_finished(path: String)

## Durée minimum (s) du voile devant la nouvelle scène.
const MIN_COVER := 0.8
## Durée maximum (s) du voile devant la nouvelle scène, même si elle rame encore.
const MAX_COVER := 8.0
## La scène est « stable » après tant d'images de suite plus courtes que STABLE_DELTA.
const STABLE_FRAMES := 15
const STABLE_DELTA := 1.0 / 30.0
const FADE_OUT := 0.7
const VEIL_DISTANCE := 1.6
const BAR_WIDTH := 0.7

const TIPS := [
	"Attache ta ceinture.",
	"Les flics ne lâchent jamais l'affaire.",
	"Une balise, ça se plie. Un sapin, non.",
	"Le colza, c'est joli. Le fossé, moins.",
	"Garde un œil sur le GPS.",
	"Les nids-de-poule ne pardonnent pas.",
	"Ne conduis pas les yeux fermés.",
]

var busy := false
## Avancement 0..1 du chargement en cours (lecture du fichier puis préparation).
var progress := 0.0

var _packed := {}       # chemin -> PackedScene déjà chargée
var _requested := {}    # chemin -> true (chargement en arrière-plan lancé)
var _veil: Node3D
var _veil_mats: Array[BaseMaterial3D] = []
var _veil_labels: Array[Label3D] = []
var _bar_fill: MeshInstance3D
var _title: Label3D
var _alpha := 0.0
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Lance le chargement de la scène en arrière-plan (sans changer de scène).
func preload_scene(path: String) -> void:
	if _packed.has(path) or _requested.has(path):
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
		_requested[path] = true


## Change de scène derrière l'écran de chargement. `fade_in` : durée du fondu au noir.
func change_scene(path: String, fade_in := 0.4) -> void:
	if busy:
		return
	busy = true
	progress = 0.0
	loading_started.emit(path)
	preload_scene(path)
	_alpha = 0.0
	_make_veil()
	# fondu au noir pendant le chargement
	var t := 0.0
	var packed: PackedScene = null
	while packed == null or t < fade_in:
		await get_tree().process_frame
		t += get_process_delta_time()
		_set_alpha(clampf(t / maxf(fade_in, 0.01), 0.0, 1.0))
		if packed == null:
			packed = _poll(path)
		_update_veil()
	# deux images pour que le voile opaque soit bien affiché avant l'à-coup
	for i in 2:
		await get_tree().process_frame
		_update_veil()
	get_tree().paused = false
	get_tree().change_scene_to_packed(packed)
	await _cover_new_scene()
	busy = false
	loading_finished.emit(path)


## Recharge la scène courante (rejouer) derrière l'écran de chargement.
func reload_current(fade_in := 0.4) -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		change_scene(scene.scene_file_path, fade_in)
	else:
		get_tree().reload_current_scene()


## Renvoie la scène chargée, ou null si elle ne l'est pas encore (met à jour progress).
func _poll(path: String) -> PackedScene:
	if _packed.has(path):
		progress = 0.85
		return _packed[path]
	var res: PackedScene = null
	if _requested.has(path):
		var p := []
		var status := ResourceLoader.load_threaded_get_status(path, p)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress = 0.85 * float(p[0]) if not p.is_empty() else progress
			return null
		_requested.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			res = ResourceLoader.load_threaded_get(path) as PackedScene
	if res == null:
		res = load(path) as PackedScene   # échec du chargement en arrière-plan : à l'ancienne
	if res:
		_packed[path] = res
		progress = 0.85
	return res


## Garde le voile devant la nouvelle scène jusqu'à ce qu'elle tourne sans à-coups.
func _cover_new_scene() -> void:
	_veil = null   # l'ancien voile part avec l'ancienne scène
	await get_tree().process_frame
	_make_veil()
	_set_alpha(1.0)
	var t := 0.0
	var stable := 0
	while t < MAX_COVER:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += minf(dt, 0.1)
		stable = stable + 1 if dt < STABLE_DELTA else 0
		progress = lerpf(0.85, 1.0, clampf(maxf(t / MIN_COVER, float(stable) / STABLE_FRAMES), 0.0, 1.0))
		_update_veil()
		if t >= MIN_COVER and stable >= STABLE_FRAMES:
			break
	progress = 1.0
	t = 0.0
	while t < FADE_OUT:
		await get_tree().process_frame
		t += minf(get_process_delta_time(), 0.05)
		_set_alpha(1.0 - t / FADE_OUT)
		_update_veil()
	if is_instance_valid(_veil):
		_veil.queue_free()
	_veil = null


# ------------------------------------------------------------------ Voile 3D

func _make_veil() -> void:
	if is_instance_valid(_veil):
		_veil.queue_free()
	_veil_mats.clear()
	_veil_labels.clear()
	_veil = Node3D.new()
	_veil.name = "LoadingVeil"
	_veil.process_mode = Node.PROCESS_MODE_ALWAYS

	# sphère sombre autour de la tête, dessinée par-dessus tout le reste
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 6.0
	sm.radial_segments = 24
	sm.rings = 12
	sphere.mesh = sm
	sphere.material_override = _veil_mat(Color(0.035, 0.04, 0.05), 120)
	_veil.add_child(sphere)

	var logo := _veil_label("NEED FOR PILS", 0.0045, Color(1, 0.72, 0.1), Vector3(0, 0.2, -VEIL_DISTANCE))
	logo.outline_size = 12
	_title = _veil_label("CHARGEMENT", 0.0016, Color(0.85, 0.87, 0.92), Vector3(0, 0.0, -VEIL_DISTANCE))
	var tip := _veil_label(TIPS[randi() % TIPS.size()], 0.0011, Color(0.6, 0.63, 0.7), Vector3(0, -0.17, -VEIL_DISTANCE))
	tip.font_size = 48

	# barre de progression
	var bg := _veil_quad(Vector2(BAR_WIDTH, 0.022), Color(0.18, 0.19, 0.22), 125)
	bg.position = Vector3(0, -0.08, -VEIL_DISTANCE - 0.001)
	_bar_fill = _veil_quad(Vector2(BAR_WIDTH, 0.022), Color(1, 0.72, 0.1), 126)
	_bar_fill.position = Vector3(0, -0.08, -VEIL_DISTANCE)
	_attach_veil()
	_set_alpha(_alpha)
	_update_veil()


func _veil_mat(col: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.render_priority = priority
	_veil_mats.append(m)
	return m


func _veil_quad(size: Vector2, col: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _veil_mat(col, priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil.add_child(mi)
	return mi


func _veil_label(text: String, pixel: float, col: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = pixel
	l.font_size = 64
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 1)
	l.no_depth_test = true
	l.shaded = false
	l.render_priority = 127
	l.outline_render_priority = 126
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil.add_child(l)
	_veil_labels.append(l)
	return l


## Accroche le voile à la caméra active (elle peut changer : caméra du casque,
## caméra du mode bureau...).
func _attach_veil() -> void:
	if not is_instance_valid(_veil):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		if _veil.get_parent() == null:
			var scene := get_tree().current_scene
			if scene:
				scene.add_child(_veil)
		return
	if _veil.get_parent() != cam:
		if _veil.get_parent():
			_veil.get_parent().remove_child(_veil)
		cam.add_child(_veil)
		_veil.transform = Transform3D.IDENTITY


func _set_alpha(a: float) -> void:
	_alpha = a
	for m in _veil_mats:
		m.albedo_color.a = a
	for l in _veil_labels:
		l.modulate.a = a
		l.outline_modulate.a = a
	if is_instance_valid(_veil):
		_veil.visible = a > 0.001


func _update_veil() -> void:
	if not is_instance_valid(_veil):
		return
	_attach_veil()
	_time += get_process_delta_time()
	if _bar_fill:
		var p := clampf(progress, 0.02, 1.0)
		_bar_fill.scale.x = p
		_bar_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - p)
	if _title:
		_title.text = "CHARGEMENT" + ".".repeat(int(_time * 2.5) % 4)
