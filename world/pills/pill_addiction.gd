class_name PillAddiction
extends Node
## Dépendance du conducteur aux pilules : le cœur de « Need for Pills ».
##
## - Le MANQUE monte en continu. Plus il est haut, plus l'image se décolore et
##   s'assombrit sur les bords, plus les mains tremblent (direction) et plus le moteur
##   perd de la puissance. À 100 % : black-out de quelques secondes, la voiture roule
##   toujours.
## - Une PILULE remet le manque à zéro, donne un BOOST (vitesse max et couple) et un
##   effet « bourré » : couleurs qui ondulent, direction en retard qui dérive.
## - Chaque pilule fait monter l'ASSIMILATION (0 à 1, ne redescend jamais) :
##   tolérance (boost et plaisir plus faibles, manque qui revient plus vite), puis
##   inversion : sobre, tout devient flou et bancal ; sous pilule, la vue redevient
##   nette. Le décor se teinte aux couleurs des pilules (paramètre global de shader
##   `pill_assimilation`, lu par nature_tint.gdshader).
##
## - La BIÈRE rend bourré, de plus en plus à chaque canette : voile ambré, bords de la
##   vue qui tanguent et dédoublent, couleurs plus vives, sons étouffés, voiture qui
##   tire d'un côté puis de l'autre avec des réactions en retard, gestes ralentis,
##   hoquet (petit à-coup dans le volant et les manettes). À partir de ~4 canettes
##   (« déchiré ») : paupières lourdes (la vue s'assombrit par vagues), vue qui se
##   resserre. Voix « je suis bourré » une fois par cuite (audio/voice/bourre.wav).
##
## Aucun effet ne bouge la caméra (confort VR) : un filtre est posé devant les yeux
## et la conduite est perturbée via SUV4x4.drug_*. Le filtre (un quad plein écran par
## œil) et le réglage des couleurs (une passe plein écran) ne sont actifs que quand un
## effet se voit : sobre et sans manque, rien n'est dessiné en plus (casque).

signal pill_taken(count: int)
signal blackout_started
## L'assimilation atteint 100 % : on est devenu l'un d'eux.
signal assimilated

const GROUP := "pill_addiction"
const OVERLAY_SHADER := preload("res://world/pills/pill_overlay.gdshader")
const RATE := 22050
## Couche de rendu du filtre : seule la caméra du joueur la voit (pas les rétros).
const OVERLAY_LAYER := 1 << 19

@export var car_path: NodePath

@export_group("Manque")
## Manque au départ (0-1).
@export_range(0.0, 1.0) var start_craving := 0.0
## Secondes pour passer de 0 à 100 % de manque, sans assimilation / assimilation max.
## Les effets se voient à partir de ~35 % (≈ 75 s sobre au début) ; le manque ne monte
## pas tant qu'on plane encore après une pilule.
@export var craving_time := Vector2(210.0, 100.0)
## Voix du personnage quand le manque s'installe (« je suis en manque bordel... »),
## une fois par épisode de manque. À remplacer : audio/voice/manque.wav.
@export_file("*.wav", "*.ogg", "*.mp3") var craving_voice_path := "res://audio/voice/manque.wav"
@export_range(0.0, 1.0) var craving_voice_at := 0.45
@export var craving_voice_db := 0.0
## Manque au réveil après un black-out.
@export_range(0.0, 1.0) var craving_after_blackout := 0.8
@export var blackout_duration := 3.5
## Perte de puissance et de vitesse max à 100 % de manque.
@export_range(0.0, 1.0) var craving_power_loss := 0.4
@export_range(0.0, 1.0) var craving_speed_loss := 0.25
## Tremblement des mains à 100 % de manque (degrés de braquage).
@export var craving_shake_deg := 2.5

@export_group("Cigarette et joint")
## Manque retiré par une cigarette / un joint fumés en entier (au prorata des bouffées).
@export var cigarette_relief := 0.35
@export var joint_relief := 0.45
## Défonce apportée par un joint entier (0-1), et secondes pour redescendre de 1 à 0.
@export var joint_stoned := 1.0
@export var stoned_fade_time := 150.0
## Défonce : le manque monte moins vite (fraction retirée à 100 %).
@export_range(0.0, 1.0) var stoned_craving_slow := 0.4

@export_group("Bière")
## Alcool gagné par canette entière (au-delà d'environ 1, on est bien bourré ; vers 2,
## déchiré). Les 6 canettes de la glacière mènent au maximum (3).
@export var alcohol_per_can := 0.5
@export var max_alcohol := 3.0
## Manque retiré par canette entière.
@export var beer_relief := 0.25
## Secondes pour éliminer 1 d'alcool.
@export var alcohol_fade_time := 360.0
## Dérive de la direction quand on est bourré, et en plus quand on est déchiré (degrés).
@export var booze_drift_deg := 7.0
@export var wasted_drift_deg := 5.0
## Hoquet quand on est bourré : secondes entre deux hoquets (bien bourré / déchiré) et
## à-coup dans le volant (degrés).
@export var hiccup_interval := Vector2(14.0, 6.0)
@export var hiccup_kick_deg := 2.5
## Voix quand on devient bien bourré (une fois par cuite).
@export var drunk_voice_id := "bourre"
@export_range(0.0, 1.0) var drunk_voice_at := 0.75

@export_group("Pilule")
## Gain d'assimilation par pilule.
@export var assimilation_per_pill := 0.08
## Durée du boost (s) et gain de vitesse max / couple, sans et avec assimilation max.
@export var boost_duration := 7.0
@export var boost_speed := Vector2(0.45, 0.15)
@export var boost_torque := Vector2(0.9, 0.3)
## Durée de l'effet « bourré » (s), sans et avec assimilation max.
@export var high_duration := Vector2(13.0, 7.0)
## Dérive de la direction quand on est bourré (degrés) et retard de la direction (0-1).
@export var drunk_drift_deg := 3.0
@export_range(0.0, 1.0) var drunk_steer_lag := 1.0
## Assimilation à partir de laquelle la sobriété devient floue (inversion).
@export var inversion_range := Vector2(0.45, 0.9)

var craving := 0.0
## Défonce du joint (0-1) : détendu, sens altérés (vue brumeuse, sons étouffés, gestes
## et volant plus lents). Ne rend pas plus rapide.
var stoned := 0.0
var alcohol := 0.0         # bière bue, s'élimine lentement
var beers := 0.0           # canettes bues (tests)
var assimilation := 0.0
var pills_taken := 0
var blackouts := 0
## Réglés par ChaseDirector : manque figé (intro, fin de partie), rideau noir (0-1) et
## proximité de la poursuivante (0-1, gyrophares sur les bords de l'image).
var paused := false
var curtain := 0.0
var chase := 0.0

var _car: Node
var _boost := 0.0       # secondes de boost restantes
var _high := 0.0        # secondes d'effet restantes
var _high_total := 1.0
var _blackout := 0.0    # secondes de black-out restantes
var _flash := 0.0       # éclair coloré à la prise
var _shown_assimilation := 0.0
var _t := 0.0
var _overlay: MeshInstance3D
var _overlay_mat: ShaderMaterial
var _env: Environment
var _heart: AudioStreamPlayer
var _gulp: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _voice_said := false
var _hiccup: AudioStreamPlayer
var _hiccup_t := 0.0
var _hiccup_kick := 0.0
var _drunk_said := false
## Hoquets (tests).
var hiccups := 0


func _ready() -> void:
	add_to_group(GROUP)
	craving = start_craving
	_car = get_node_or_null(car_path)
	_heart = AudioStreamPlayer.new()
	_heart.name = "Heartbeat"
	GeneratedSound.make_later(_make_heartbeat, _heart, &"stream")
	_heart.volume_db = -80.0
	add_child(_heart)
	_gulp = AudioStreamPlayer.new()
	_gulp.name = "PillSound"
	GeneratedSound.make_later(_make_pill_sound, _gulp, &"stream")
	_gulp.volume_db = -4.0
	add_child(_gulp)
	_voice = AudioStreamPlayer.new()
	_voice.name = "CravingVoice"
	if ResourceLoader.exists(craving_voice_path):
		_voice.stream = load(craving_voice_path) as AudioStream
	_voice.volume_db = craving_voice_db
	add_child(_voice)
	_hiccup = AudioStreamPlayer.new()
	_hiccup.name = "Hiccup"
	GeneratedSound.make_later(_make_hiccup, _hiccup, &"stream")
	_hiccup.volume_db = -3.0
	add_child(_hiccup)
	RenderingServer.global_shader_parameter_set("pill_assimilation", 0.0)


# --- État lisible par d'autres scripts ------------------------------------

func is_boosting() -> bool:
	return _boost > 0.0


func is_blackout() -> bool:
	return _blackout > 0.0


## Effet de la dernière pilule (0-1), qui retombe avec le temps.
func get_high() -> float:
	return clampf(_high / _high_total, 0.0, 1.0)


## Intensité de l'effet « bourré » (0-1). Avec l'inversion, c'est la sobriété qui
## rend bourré et la pilule qui rend la vue nette.
func get_drunk() -> float:
	var high := get_high()
	var tolerance := 1.0 - 0.65 * assimilation
	var inversion := smoothstep(inversion_range.x, inversion_range.y, assimilation)
	return maxf(high * tolerance * (1.0 - inversion), inversion * (1.0 - high))


## Bouffée de cigarette ou de joint : `fraction` = part de l'objet fumée pendant cette
## bouffée (appelé à chaque image par Smokable).
func smoke(kind: String, fraction: float) -> void:
	var relief := joint_relief if kind == "joint" else cigarette_relief
	craving = maxf(craving - relief * fraction, 0.0)
	if kind == "joint":
		stoned = minf(stoned + joint_stoned * fraction, 1.0)


## Défonce actuelle (0-1) du joueur, 0 sans PillAddiction (gestes, son...).
## Gestes ralentis (défoncé, ou bourré) : saisies retardées, objets qui suivent la main
## avec du retard.
static func stoned_level(tree: SceneTree) -> float:
	var a := tree.get_first_node_in_group(GROUP)
	if a == null:
		return 0.0
	return maxf(float(a.get("stoned")), 0.75 * float(a.call("get_booze")))


## Ivresse (0-1) due à la bière : bien bourré vers 2 canettes et demie.
func get_booze() -> float:
	return smoothstep(0.1, 1.3, alcohol)


## Au-delà de bourré (0-1) : déchiré vers 5 canettes.
func get_wasted() -> float:
	return smoothstep(1.4, 2.6, alcohol)


## Gorgée de bière : `amount` = part de canette bue.
func drink_beer(amount: float) -> void:
	alcohol = minf(alcohol + alcohol_per_can * amount, max_alcohol)
	craving = maxf(craving - beer_relief * amount, 0.0)
	beers += amount


# --- Prise d'une pilule ------------------------------------------------------

func take_pill() -> void:
	pills_taken += 1
	# Reprendre une pilule alors qu'on plane encore : on s'assimile plus vite.
	var greedy := 1.5 if _high > 0.5 * _high_total else 1.0
	var was_full := assimilation >= 1.0
	assimilation = clampf(assimilation + assimilation_per_pill * greedy, 0.0, 1.0)
	craving = 0.0
	_voice_said = false
	_blackout = 0.0
	_boost = boost_duration
	_high_total = lerpf(high_duration.x, high_duration.y, assimilation)
	_high = _high_total
	_flash = 1.0
	_gulp.pitch_scale = randf_range(0.95, 1.08)
	_gulp.play()
	pill_taken.emit(pills_taken)
	if assimilation >= 1.0 and not was_full:
		assimilated.emit()


# --- Boucle ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if _car == null:
		_car = get_node_or_null(car_path)
	_boost = maxf(_boost - delta, 0.0)
	_high = maxf(_high - delta, 0.0)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	if paused:
		pass
	elif _blackout > 0.0:
		_blackout = maxf(_blackout - delta, 0.0)
		if _blackout == 0.0:
			craving = craving_after_blackout
	elif _high <= 0.0:
		var slow := 1.0 - stoned_craving_slow * stoned
		craving = minf(craving + slow * delta / lerpf(craving_time.x, craving_time.y, assimilation), 1.0)
		if craving >= craving_voice_at and not _voice_said:
			_voice_said = true
			if _voice.stream:
				_voice.play()
				print("Voix de manque : ", craving_voice_path)
		if craving >= 1.0:
			_blackout = blackout_duration
			blackouts += 1
			blackout_started.emit()
	stoned = move_toward(stoned, 0.0, delta / stoned_fade_time)
	alcohol = move_toward(alcohol, 0.0, delta / alcohol_fade_time)
	_update_hiccups(delta)
	_apply_to_car()


func _apply_to_car() -> void:
	if _car == null or not ("drug_speed_mult" in _car):
		return
	var tol := 1.0 - assimilation
	# Boost : plein pendant la durée, puis s'éteint sur la dernière seconde et demie.
	var b := clampf(_boost / 1.5, 0.0, 1.0)
	var speed := 1.0 + b * lerpf(boost_speed.y, boost_speed.x, tol)
	var torque := 1.0 + b * lerpf(boost_torque.y, boost_torque.x, tol)
	# Manque : le moteur s'essouffle au-delà d'un tiers de manque (seulement hors boost).
	var c := smoothstep(0.35, 1.0, craving) * (1.0 - b)
	speed *= 1.0 - craving_speed_loss * c
	torque *= 1.0 - craving_power_loss * c
	_car.drug_speed_mult = speed
	_car.drug_torque_mult = torque
	# Direction : mains qui tremblent (manque) + dérive lente et retard (bourré).
	var drunk := get_drunk()
	var shake := deg_to_rad(craving_shake_deg) * c * (sin(_t * 23.0) * 0.6 + sin(_t * 37.0) * 0.4)
	var drift := deg_to_rad(drunk_drift_deg) * drunk * (sin(_t * 0.7) * 0.7 + sin(_t * 1.9 + 1.3) * 0.3)
	# défoncé : direction un peu molle et flottante, mais pas plus de vitesse
	var st := smoothstep(0.0, 1.0, stoned)
	drift += deg_to_rad(1.2) * st * sin(_t * 0.45 + 0.7)
	# bourré (bière) : la voiture tire d'un côté puis de l'autre, réactions en retard
	var bz := get_booze()
	var bdrift := booze_drift_deg * bz + wasted_drift_deg * get_wasted()
	drift += deg_to_rad(bdrift) * (sin(_t * 0.37 + 2.1) * 0.65 + sin(_t * 1.13) * 0.35)
	drift += deg_to_rad(hiccup_kick_deg) * _hiccup_kick
	_car.drug_steer_offset = shake + drift
	_car.drug_steer_lag = clampf(drunk * drunk_steer_lag + 0.45 * st + 0.6 * bz, 0.0, 1.0)


func _process(delta: float) -> void:
	_ensure_overlay()
	_hide_from_other_cameras()
	var drunk := get_drunk()
	var high := get_high()
	# Battement de cœur : de plus en plus fort et rapide avec le manque.
	var hb := maxf(smoothstep(0.35, 1.0, craving) * (1.0 - high), 1.0 if _blackout > 0.0 else 0.0)
	_heart.pitch_scale = lerpf(0.85, 1.7, craving)
	_heart.volume_db = linear_to_db(maxf(hb, 0.0001)) - 2.0
	if hb > 0.01 and not _heart.playing:
		_heart.play()
	elif hb <= 0.01 and _heart.playing:
		_heart.stop()
	var pulse := pow(0.5 + 0.5 * sin(_t * TAU * 1.2 * _heart.pitch_scale), 6.0)
	var blackout := 0.0
	if _blackout > 0.0:
		# fondu au noir rapide, retour progressif sur la dernière seconde
		blackout = clampf((blackout_duration - _blackout) / 0.4, 0.0, 1.0) * clampf(_blackout / 1.0, 0.0, 1.0)
	if _overlay:
		var cv := craving * (1.0 - high)
		_overlay.visible = cv > 0.15 or drunk > 0.002 or blackout > 0.002 or curtain > 0.002 \
				or chase > 0.002 or _flash > 0.002 or stoned > 0.002 or alcohol > 0.05
	if _overlay_mat and _overlay.visible:
		_overlay_mat.set_shader_parameter("craving", craving * (1.0 - high))
		_overlay_mat.set_shader_parameter("drunk", drunk)
		_overlay_mat.set_shader_parameter("blackout", maxf(blackout, curtain))
		_overlay_mat.set_shader_parameter("chase", chase)
		_overlay_mat.set_shader_parameter("flash", _flash)
		_overlay_mat.set_shader_parameter("pulse", pulse)
		_overlay_mat.set_shader_parameter("assimilation", assimilation)
		_overlay_mat.set_shader_parameter("stoned", smoothstep(0.0, 1.0, stoned))
		_overlay_mat.set_shader_parameter("booze", get_booze())
		_overlay_mat.set_shader_parameter("wasted", get_wasted())
		_overlay_mat.set_shader_parameter("hiccup", _hiccup_kick)
	if _env:
		# Couleurs : délavées en manque, saturées sous pilule.
		var sat := lerpf(1.0, 0.2, craving * (1.0 - high)) + 0.8 * high * (1.0 - assimilation) + 0.6 * drunk
		var st := smoothstep(0.0, 1.0, stoned)
		var bz := get_booze()
		_env.adjustment_saturation = sat + 0.25 * st + 0.35 * bz
		_env.adjustment_contrast = 1.0 + 0.15 * drunk - 0.18 * st + 0.12 * bz
		_env.adjustment_brightness = 1.0 + 0.06 * st
		# au neutre, pas de passe de réglage des couleurs (coûteuse dans le casque)
		_env.adjustment_enabled = absf(_env.adjustment_saturation - 1.0) > 0.01 \
				or absf(_env.adjustment_contrast - 1.0) > 0.01 or absf(_env.adjustment_brightness - 1.0) > 0.01
	_update_stoned_audio()
	# Le décor se teinte doucement (paramètre global lu par nature_tint.gdshader).
	_shown_assimilation = move_toward(_shown_assimilation, assimilation, delta * 0.1)
	RenderingServer.global_shader_parameter_set("pill_assimilation", _shown_assimilation)


## Défoncé : tous les sons un peu étouffés et lointains (passe-bas sur le bus principal).
var _master_lp: AudioEffectLowPassFilter
func _update_stoned_audio() -> void:
	var st := maxf(smoothstep(0.0, 1.0, stoned), 0.7 * get_booze())
	if _master_lp == null:
		if st < 0.01:
			return
		_master_lp = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(0, _master_lp)
	_master_lp.cutoff_hz = lerpf(20000.0, 2200.0, st)
	var idx := -1
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _master_lp:
			idx = i
	if idx >= 0:
		AudioServer.set_bus_effect_enabled(0, idx, st > 0.01)


func _exit_tree() -> void:
	if _master_lp:
		for i in AudioServer.get_bus_effect_count(0):
			if AudioServer.get_bus_effect(0, i) == _master_lp:
				AudioServer.remove_bus_effect(0, i)
				break


## Filtre plein écran collé devant la caméra active (VR ou bureau).
func _ensure_overlay() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _overlay and is_instance_valid(_overlay) and _overlay.get_parent() == cam:
		return
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = MeshInstance3D.new()
	_overlay.name = "PillOverlay"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_overlay.mesh = quad
	_overlay.position = Vector3(0.0, 0.0, -maxf(cam.near * 1.6, 0.08))
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.extra_cull_margin = 16384.0
	_overlay.layers = OVERLAY_LAYER
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.render_priority = 100   # sous les textes de ChaseDirector
	_overlay.material_override = _overlay_mat
	cam.add_child(_overlay)
	cam.cull_mask |= OVERLAY_LAYER
	var world := cam.get_world_3d()
	_env = world.environment if world else null


## Les rétroviseurs ont leurs propres caméras, qui regardent vers le conducteur :
## elles ne doivent pas voir le filtre collé devant ses yeux.
func _hide_from_other_cameras() -> void:
	if Engine.get_process_frames() % 30 != 0 or _overlay == null:
		return
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if c != _overlay.get_parent():
			(c as Camera3D).cull_mask &= ~OVERLAY_LAYER


## Hoquet quand on est bourré (son, à-coup dans le volant, petite vibration des
## manettes), et la voix « je suis bourré » une fois par cuite.
func _update_hiccups(delta: float) -> void:
	_hiccup_kick = move_toward(_hiccup_kick, 0.0, delta * 4.0)
	var bz := get_booze()
	if bz >= drunk_voice_at and not _drunk_said and not paused:
		_drunk_said = true
		VoiceLine.play(self, drunk_voice_id, "perso")
	elif bz < 0.2:
		_drunk_said = false
	if bz < 0.45 or paused:
		_hiccup_t = 0.0
		return
	if _hiccup_t <= 0.0:
		_hiccup_t = randf_range(0.6, 1.4) * lerpf(hiccup_interval.x, hiccup_interval.y, get_wasted())
	_hiccup_t -= delta
	if _hiccup_t <= 0.0:
		hiccup()


func hiccup() -> void:
	hiccups += 1
	_hiccup_kick = 1.0 if randf() < 0.5 else -1.0
	_hiccup.pitch_scale = randf_range(0.9, 1.12)
	_hiccup.play()
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(0.35, 0.07)


# --- Sons générés par code ------------------------------------------------------

func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w


## Battement de cœur « poum-poum » en boucle (1 s à hauteur normale).
func _make_heartbeat() -> AudioStreamWAV:
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for beat in [[0.0, 1.0], [0.26, 0.7]]:
			var dt: float = t - beat[0]
			if dt >= 0.0:
				v += sin(TAU * (48.0 + 30.0 * exp(-dt * 30.0)) * dt) * exp(-dt * 18.0) * beat[1]
		s[i] = v * 0.9
	return _wav(s, true)


## Hoquet « hic » : petit claquement de glotte puis un « i » bref qui monte.
func _make_hiccup() -> AudioStreamWAV:
	var n := int(RATE * 0.24)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f0 := 210.0 + 140.0 * minf(t / 0.06, 1.0)
		ph += f0 / RATE
		var v := 0.0
		for k in range(1, 16):
			var fk := f0 * k
			var w := exp(-pow((fk - 420.0) / 160.0, 2.0)) + 0.55 * exp(-pow((fk - 2300.0) / 450.0, 2.0))
			v += sin(TAU * ph * k) * w
		var env := minf(t / 0.006, 1.0) * exp(-maxf(t - 0.02, 0.0) * 22.0)
		var click := randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6
		s[i] = (v * 0.35 * env + click) * 0.9
	return _wav(s)


## Prise d'une pilule : « glup » grave puis scintillement montant.
func _make_pill_sound() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var gulp := sin(TAU * (220.0 - 140.0 * t / 0.12) * t) * exp(-t * 30.0) if t < 0.12 else 0.0
		var f := 300.0 + 1500.0 * pow(t / 0.9, 1.6)
		ph = fmod(ph + f / RATE, 1.0)
		ph2 = fmod(ph2 + f * 1.5 / RATE, 1.0)
		var env := clampf((t - 0.08) / 0.1, 0.0, 1.0) * clampf((0.9 - t) / 0.4, 0.0, 1.0)
		var sparkle := (sin(TAU * ph) * 0.6 + sin(TAU * ph2) * 0.3) * (0.7 + 0.3 * sin(t * 90.0))
		s[i] = gulp * 0.8 + sparkle * env * 0.35
	return _wav(s)
