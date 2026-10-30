extends Node
## Banc de mesure sur le casque (lancé par l'option `--perftest`, avec `--solo`) :
## voiture garée, on éteint une à une les fonctions lourdes pendant `PHASE_TIME`
## secondes chacune et on écrit « PERFTEST phase ... » dans le journal. Le temps GPU
## de chaque phase se lit dans les lignes VrApi du journal du Quest (adb logcat).
## Rester assis, la tête immobile, regard vers l'avant pendant toute la mesure.

const PHASE_TIME := 6.0
const START_DELAY := 8.0
const PHASES := ["neutre", "reglage_couleurs", "filtre_plein_ecran", "sans_msaa", "sans_retros",
		"sans_lumieres", "sans_vitres", "sans_decor", "sans_ciel_brouillard", "resolution_70", "neutre_fin"]

var _t := 0.0
var _phase := -1
var _env: Environment
var _addiction: Node


func _process(delta: float) -> void:
	if get_tree().get_first_node_in_group(SUV4x4.GROUP) == null:
		return   # partie pas encore chargée
	_t += delta
	if _t < START_DELAY:
		return
	var p := int((_t - START_DELAY) / PHASE_TIME)
	if p == _phase:
		return
	if p >= PHASES.size():
		print("PERFTEST fin")
		_restore()
		queue_free()
		return
	_restore()
	_phase = p
	_apply(PHASES[p])
	print("PERFTEST phase %d %s" % [p, PHASES[p]])


func _ready_refs() -> void:
	if _env == null:
		var cam := get_viewport().get_camera_3d()
		var w := cam.get_world_3d() if cam else null
		_env = w.environment if w else null
	if _addiction == null:
		_addiction = get_tree().get_first_node_in_group(PillAddiction.GROUP)
		if _addiction:
			_addiction.set_process(false)   # c'est nous qui réglons filtre et couleurs


func _restore() -> void:
	_ready_refs()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().scaling_3d_scale = 1.0
	for m in _all("VRMirror"):
		m.set_process(true)
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		if l.has_meta("_perf_hidden"):
			l.remove_meta("_perf_hidden")
			l.visible = true
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if n.has_meta("_perf_hidden"):
			n.remove_meta("_perf_hidden")
			n.visible = true
	if _env:
		_env.adjustment_enabled = false
		_env.fog_enabled = true
		_env.background_mode = Environment.BG_SKY
	var ov := get_tree().root.find_child("PillOverlay", true, false) as Node3D
	if ov:
		ov.visible = false
		if _addiction:
			_addiction.set("craving", 0.0)


func _apply(phase: String) -> void:
	match phase:
		"reglage_couleurs":
			if _env:
				_env.adjustment_enabled = true
				_env.adjustment_saturation = 0.8
		"filtre_plein_ecran":
			var ov := get_tree().root.find_child("PillOverlay", true, false) as MeshInstance3D
			if ov:
				ov.visible = true
				(ov.material_override as ShaderMaterial).set_shader_parameter("craving", 0.5)
		"sans_msaa":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		"sans_retros":
			for m in _all("VRMirror"):
				m.set_process(false)
				var vp: SubViewport = m.get("_viewport")
				if vp:
					vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		"sans_lumieres":
			for l in get_tree().root.find_children("*", "Light3D", true, false):
				if l.visible and not (l is DirectionalLight3D):
					l.visible = false
					l.set_meta("_perf_hidden", true)
		"sans_vitres":
			for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi and mi.visible and (mi.name == "Window" or mi is WindshieldRain or _has_glass(mi)):
					mi.visible = false
					mi.set_meta("_perf_hidden", true)
		"sans_decor":
			for n in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
				if n.visible:
					n.visible = false
					n.set_meta("_perf_hidden", true)
		"sans_ciel_brouillard":
			if _env:
				_env.fog_enabled = false
				_env.background_mode = Environment.BG_COLOR
		"resolution_70":
			get_viewport().scaling_3d_scale = 0.7


func _has_glass(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.mesh.get_surface_count() != 1:
		return false
	return mi.get_active_material(0) is ShaderMaterial and str((mi.get_active_material(0) as ShaderMaterial).shader.resource_path).contains("car_glass")


func _all(cls: String) -> Array:
	var out := []
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n.get_script() and n.get_script().get_global_name() == cls:
			out.append(n)
	return out
