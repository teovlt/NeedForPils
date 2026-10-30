extends Node3D
## Autoradio au centre du tableau de bord + 4 haut-parleurs (un par portière).
##
## - Marche seulement contact mis (clé sur I ou II), comme une vraie voiture.
## - Bouton de volume (à gauche) : le saisir et le tourner (VR : poignet ; souris :
##   glisser vers la droite / la gauche). F sur le bouton : marche / arrêt.
## - Touche PWR (en bas à droite) : marche / arrêt (l'écran et sa lueur s'éteignent).
## - Touches ◀ ▶ : station précédente / suivante (petit grésillement entre deux).
##   Touches 1 à 4 : stations mémorisées. Saisir une touche ou F : l'enfoncer.
## - Station « PILS MIX » (5e, avec ◀ ▶) : joue les musiques du dossier
##   res://audio/radio/playlist/ (mp3, ogg ou wav), dans un ordre tiré au hasard à
##   chaque partie, l'une après l'autre. Pour ajouter une musique : déposer le fichier
##   dans ce dossier et ouvrir une fois l'éditeur Godot (il l'importe). Le titre affiché
##   est le nom du fichier.
## - Écran : fréquence et nom de la station, volume quand on le règle.
## - Le son sort de 4 AudioStreamPlayer3D enfants des portières : porte ouverte,
##   son haut-parleur tourne avec elle et le son vient d'ailleurs.
## - Les stations « tournent » même radio éteinte : on retombe au milieu d'un morceau.
##   Pour la playlist, c'est la vraie fin du morceau (signal `finished`) qui lance le
##   suivant : un lecteur qui vient d'être lancé ne dit pas encore qu'il joue (le
##   relancer superposait deux lectures).
## - Playlist : chaque morceau (mp3, ogg) est décodé à l'avance en WAV en mémoire, dans un
##   fil de travail (celui en cours et le suivant ; ~40 Mo par morceau de 4 min,
##   décodé par tranches pour ne pas dépasser cette taille en mémoire). Caler un mp3
##   au milieu du morceau prend ~60 ms (bien plus sur le casque) et
##   AudioStreamPlayer3D.play(position) le fait sur le fil principal, une fois par
##   haut-parleur : l'image saccadait et les 4 haut-parleurs partaient décalés (son
##   décalé entre gauche et droite). Un WAV se cale instantanément : ils partent
##   ensemble. Tant que le morceau n'est pas prêt (début de partie), grésillement.
##   Les fichiers ne sont pas chargés au démarrage (~56 Mo pour 10 morceaux : ça
##   figeait le lancement) : le fil de travail charge celui qu'il décode. D'ici là, la
##   durée d'un morceau est estimée (`PLAYLIST_GUESS_LENGTH`), puis corrigée.
## - La nuit, l'écran allumé laisse échapper une légère lueur bleutée sur la console et
##   le tableau de bord (rien en plein jour : elle suit l'obscurité de la météo).
## Clavier (test) : F2 / F3 station précédente / suivante, F4 marche / arrêt,
## F9 / F10 volume - / +.
##
## Repère du noeud : origine = dos de la façade, +Z vers le conducteur, +X à droite vu
## du conducteur.

const STATIONS := [
	{"freq": "88.5", "name": "PILS FM", "file": "res://audio/radio/pils_fm.wav"},
	{"freq": "92.1", "name": "RADIO BITUME", "file": "res://audio/radio/radio_bitume.wav"},
	{"freq": "97.3", "name": "LOUNGE 97", "file": "res://audio/radio/lounge_973.wav"},
	{"freq": "103.7", "name": "DISCO PILULE", "file": "res://audio/radio/disco_pilule.wav"},
	{"freq": "106.9", "name": "PILS MIX", "playlist": "res://audio/radio/playlist"},
]
## Formats acceptés dans le dossier d'une station « playlist ».
const PLAYLIST_EXT := ["mp3", "ogg", "wav"]
## Largeur de l'écran pour le titre défilant (caractères).
const TITLE_CHARS := 13
const STATIC_FILE := "res://audio/radio/static.wav"
## Haut-parleurs : [porte, position dans le repère de la porte, côté (1 = gauche : face vers
## -X), taille de la grille]. Grille plaquée sur le panneau intérieur (x = ±0,85 dans la
## voiture), là où on la voit depuis les sièges : à l'avant entre le vide-poche et
## l'accoudoir, bien en arrière du tableau de bord (avant, ils étaient dans son
## épaisseur, invisibles, et le son sortait de derrière lui) ; à l'arrière au-dessus de
## l'accoudoir, au milieu de la portière (plus bas, l'accoudoir les cachait). Le son sort de la
## grille et suit la portière quand on l'ouvre.
const SPEAKERS := [
	["Doors/DoorFL", Vector3(-0.10, 0.43, -0.395), 1.0, 0.75],
	["Doors/DoorFR", Vector3(0.10, 0.43, -0.395), -1.0, 0.75],
	["Doors/DoorRL", Vector3(-0.10, 0.37, -0.475), 1.0, 0.75],
	["Doors/DoorRR", Vector3(0.10, 0.37, -0.475), -1.0, 0.75],
]
const KNOB_POS := Vector3(-0.068, 0.0, 0.014)
const KNOB_SWEEP_DEG := 300.0

@export var power := true
@export_range(0.0, 1.0) var volume := 0.45
@export var station := 0
## Gain général des haut-parleurs (dB) à volume maxi.
@export var max_volume_db := 4.0
## Lueur de l'écran la nuit (énergie dans l'obscurité totale).
@export var screen_glow_energy := 0.16
@export var screen_glow_color := Color(0.55, 0.85, 1.0)
## Gain des musiques de la playlist (dB) : des morceaux du commerce sont mixés plus
## fort que les stations générées.
@export var playlist_gain_db := -4.0

var car: Node3D
var speakers: Array[AudioStreamPlayer3D] = []

var _streams: Array[AudioStreamWAV] = []
var _static: AudioStreamWAV
var _offsets: Array[float] = []
var _clock := 0.0
var _tuning := 0.0
var _loaded := -2          # ce que jouent les haut-parleurs : -2 rien, -1 grésillement, i station
var _playlist: Array[Dictionary] = []   # {title, stream, length}, dans l'ordre de passage
var _playlist_total := 0.0
var _track := -1           # morceau de la playlist en cours dans les haut-parleurs
var _pl_index := 0         # morceau en cours de la playlist (même radio éteinte)
var _pl_started := 0.0     # instant (_clock) où ce morceau a commencé
var _decoded := {}         # morceau de la playlist -> AudioStreamWAV décodé (en cours, suivant)
var _decode_task := -1     # tâche WorkerThreadPool en cours (-1 : aucune)
var _decode_track := -1    # ... morceau qu'elle décode
var _decode_out: AudioStreamWAV   # ... son résultat (écrit par le fil de travail)
var _show_vol := 0.0
var _knob: Node3D
var _knob_grip: VRInteractable
var _buttons := {}         # nom -> [noeud, position de repos]
var _freq_lbl: Label3D
var _name_lbl: Label3D
var _glow: SpotLight3D
var _glow_level := 0.0


class Grip extends VRInteractable:
	var radio: Node
	var kind := ""
	func _on_grab_begin(h: Node3D) -> void: radio._grip_begin(kind, h)
	func _on_grab_update(h: Node3D) -> void: radio._grip_update(kind, h)
	func _on_grab_end(h: Node3D) -> void: radio._grip_end(kind, h)
	func toggle() -> void: radio._grip_toggle(kind)


func _ready() -> void:
	var parts: Node3D = preload("res://cars/SUV4x4/car_radio_parts.glb").instantiate()
	add_child(parts)
	var body := parts.get_node("Radio_Body") as Node3D
	body.reparent(self, false)
	body.transform = Transform3D.IDENTITY
	# bouton de volume
	_knob_grip = _make_grip("knob", KNOB_POS, 0.06, 0.035)
	_knob = parts.get_node("Radio_Knob") as Node3D
	_knob.reparent(_knob_grip, false)
	_knob.transform = Transform3D.IDENTITY
	# touches
	var btn_defs := [["prev", "Radio_BtnPrev", Vector3(0.060, 0.010, 0.014), ""],
		["next", "Radio_BtnNext", Vector3(0.080, 0.010, 0.014), ""]]
	for i in 4:
		btn_defs.append(["p%d" % i, "Radio_Preset", Vector3(-0.0345 + 0.023 * i, -0.0165, 0.014), str(i + 1)])
	btn_defs.append(["power", "Radio_Preset", Vector3(0.070, -0.0165, 0.014), "PWR"])
	for d in btn_defs:
		# zones de saisie serrées : les touches sont à 3 mm les unes des autres
		var g := _make_grip(d[0], d[2], 0.04, 0.011)
		var src := parts.get_node(d[1]) as Node3D
		var m: Node3D = src.duplicate() if d[1] == "Radio_Preset" else src
		if m == src:
			src.reparent(g, false)
		else:
			g.add_child(m)
		m.transform = Transform3D.IDENTITY
		_buttons[d[0]] = [m, Vector3.ZERO]
		if d[3] != "":
			var power_btn: bool = d[0] == "power"
			var l := _label(d[3], 40, Color(1.0, 0.45, 0.35) if power_btn else Color(0.92, 0.92, 0.9))
			l.pixel_size = 0.00007 if power_btn else 0.00011
			l.position = Vector3(0, 0, 0.0039)
			g.add_child(l)
	var vol_lbl := _label("VOL", 28, Color(0.75, 0.76, 0.78))
	vol_lbl.pixel_size = 0.0001
	vol_lbl.position = KNOB_POS + Vector3(0.0, 0.0215, 0.0001)
	add_child(vol_lbl)
	# haut-parleurs de portières (grille + son)
	var grille_src := parts.get_node("Speaker_Grille") as Node3D
	for sp in SPEAKERS:
		var door := car.get_node(sp[0]) as Node3D
		var side: float = sp[2]
		var z := Vector3(-side, 0.0, 0.0)
		var xf := Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), sp[1])
		var g2 := grille_src.duplicate() as Node3D
		g2.name = "SpeakerGrille"
		g2.transform = xf.scaled_local(Vector3.ONE * float(sp[3]))
		door.add_child(g2)
		var p := AudioStreamPlayer3D.new()
		p.name = "RadioSpeaker"
		p.transform = xf.translated_local(Vector3(0, 0, 0.01))
		p.unit_size = 1.6
		p.max_db = 6.0
		p.max_distance = 35.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -8.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		door.add_child(p)
		speakers.append(p)
	parts.queue_free()
	# écran
	_freq_lbl = _label("", 64, Color(0.55, 0.92, 1.0))
	_freq_lbl.pixel_size = 0.00016
	_freq_lbl.position = Vector3(0.0, 0.0135, 0.0146)
	add_child(_freq_lbl)
	_name_lbl = _label("", 48, Color(0.55, 0.92, 1.0))
	_name_lbl.pixel_size = 0.000105
	_name_lbl.position = Vector3(0.0, 0.0025, 0.0146)
	add_child(_name_lbl)
	# lueur de l'écran : petit projecteur doux devant l'écran, tourné vers le conducteur
	_glow = SpotLight3D.new()
	_glow.name = "ScreenGlow"
	_glow.position = Vector3(0.0, 0.0095, 0.03)
	_glow.rotation = Vector3(0.0, PI, 0.0)
	_glow.spot_range = 0.45
	_glow.spot_angle = 80.0
	_glow.spot_attenuation = 1.8
	_glow.spot_angle_attenuation = 0.5
	_glow.light_color = screen_glow_color
	_glow.light_specular = 0.05
	_glow.shadow_enabled = false
	_glow.visible = false
	add_child(_glow)
	# sons
	for s in STATIONS:
		if s.has("playlist"):
			_load_playlist(s["playlist"])
			_streams.append(null)
			_offsets.append(0.0)
			# on tombe au milieu d'un morceau tiré au hasard
			_pl_index = randi() % maxi(_playlist.size(), 1)
			if not _playlist.is_empty():
				_pl_started = -randf() * float(_playlist[_pl_index]["length"]) * 0.8
			continue
		var w := load(s["file"]) as AudioStreamWAV
		_prepare_loop(w)
		_streams.append(w)
		_offsets.append(randf() * 60.0)
	_static = load(STATIC_FILE) as AudioStreamWAV
	_prepare_loop(_static)
	if not speakers.is_empty():
		speakers[0].finished.connect(_on_track_finished)
	_apply_knob()


func _make_grip(kind: String, pos: Vector3, hl: float, gd: float) -> VRInteractable:
	var g := Grip.new()
	g.name = "Radio_" + kind
	g.radio = self
	g.kind = kind
	g.position = pos
	g.highlight_distance = hl
	g.grab_distance = gd
	g.outline_width = 0.0015
	g.pick_bonus = 0.03 if kind == "knob" else 0.035
	add_child(g)
	return g


func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l


## Durée supposée d'un morceau pas encore chargé (s).
const PLAYLIST_GUESS_LENGTH := 210.0


## Liste les musiques d'un dossier (ordre aléatoire, sans boucle) ; elles sont
## chargées plus tard, une à une, par le fil de décodage.
func _load_playlist(dir: String) -> void:
	var files := PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		files = ResourceLoader.list_directory(dir)   # marche aussi dans le jeu exporté
	else:
		for f in DirAccess.get_files_at(dir):
			files.append(f.trim_suffix(".import").trim_suffix(".remap"))
	var names: Array[String] = []
	for f in files:
		if f.get_extension().to_lower() in PLAYLIST_EXT and not names.has(f):
			names.append(f)
	names.shuffle()
	for f in names:
		_playlist.append({"title": f.get_basename(), "path": dir.path_join(f), "length": PLAYLIST_GUESS_LENGTH})
		_playlist_total += PLAYLIST_GUESS_LENGTH


## Décodage en mémoire des morceaux de la playlist (voir l'en-tête) : celui en cours et
## le suivant, un à la fois, dans un fil de travail. Appelé à chaque image.
func _update_decoding() -> void:
	if _playlist.is_empty():
		return
	if _decode_task >= 0:
		if not WorkerThreadPool.is_task_completed(_decode_task):
			return
		WorkerThreadPool.wait_for_task_completion(_decode_task)
		_decode_task = -1
		if _decode_out:
			_decoded[_decode_track] = _decode_out
			# durée exacte (celle annoncée par un mp3 est approximative)
			var old_len: float = _playlist[_decode_track]["length"]
			_playlist[_decode_track]["length"] = _decode_out.get_length()
			_playlist_total += _decode_out.get_length() - old_len
		_decode_out = null
		# morceau attendu (grésillement en attendant) : on le lance
		if _is_playlist(_loaded) and _track < 0 and _decoded.has(_playlist_now()[0]):
			_load(_loaded)
	var cur: int = _track if _track >= 0 else _playlist_now()[0]
	var wanted := [cur, (cur + 1) % _playlist.size()]
	for k in _decoded.keys():
		if k not in wanted:
			_decoded.erase(k)   # libère la mémoire des morceaux passés
	for i in wanted:
		if not _decoded.has(i):
			_decode_track = i
			_decode_task = WorkerThreadPool.add_task(_decode_job.bind(_playlist[i]["path"], AudioServer.get_mix_rate()), false, "Radio : décodage")
			return


## Fil de travail : décode tout le morceau et en fait un WAV (16 bits) en mémoire.
## Par tranches de ~1,5 s converties tout de suite en 16 bits : la mémoire ne dépasse
## pas la taille du WAV final (~65 Mo pour 6 min ; tout décoder en flottants d'abord
## montait à ~330 Mo, risqué sur le casque).
func _decode_job(path: String, rate: float) -> void:
	var src := load(path) as AudioStream
	if src == null:
		_decode_out = null
		return
	if src is AudioStreamWAV:
		(src as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_decode_out = src   # déjà décodé
		return
	if "loop" in src:
		src.set("loop", false)
	var pb := src.instantiate_playback()
	pb.start(0.0)
	var need := int(src.get_length() * rate)
	var pcm16 := PackedByteArray()
	var frames := 0
	while frames < need:
		var a := pb.mix_audio(1.0, mini(65536, need - frames))
		if a.is_empty():
			break
		frames += a.size()
		var chunk := _float_to_wav16(a.to_byte_array(), rate)   # flottants 32 bits, gauche / droite
		if chunk == null:
			break
		pcm16.append_array(chunk.data)
	pb.stop()
	if pcm16.is_empty():
		_decode_out = null
		return
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = int(rate)
	w.data = pcm16
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_decode_out = w


## Tranche de flottants 32 bits stéréo -> WAV 16 bits (le lecteur WAV de Godot convertit
## un en-tête « IEEE float »).
static func _float_to_wav16(pcm: PackedByteArray, rate: float) -> AudioStreamWAV:
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)    # RIFF
	h.encode_u32(4, 36 + pcm.size())
	h.encode_u32(8, 0x45564157)    # WAVE
	h.encode_u32(12, 0x20746d66)   # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 3)            # IEEE float
	h.encode_u16(22, 2)
	h.encode_u32(24, int(rate))
	h.encode_u32(28, int(rate) * 8)
	h.encode_u16(32, 8)
	h.encode_u16(34, 32)
	h.encode_u32(36, 0x61746164)   # data
	h.encode_u32(40, pcm.size())
	h.append_array(pcm)
	return AudioStreamWAV.load_from_buffer(h, {"compress/mode": 0})


func _exit_tree() -> void:
	if _decode_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_decode_task)
		_decode_task = -1


func _is_playlist(i: int) -> bool:
	return i >= 0 and STATIONS[i].has("playlist")


## Morceau et position dans la playlist à l'instant présent : [index, secondes]. Tant
## qu'on ne l'écoute pas, la station « tourne » d'après les durées annoncées.
func _playlist_now() -> Array:
	if _playlist.is_empty():
		return [-1, 0.0]
	if _track < 0:   # pas dans les haut-parleurs : on avance au fil des durées
		while _clock - _pl_started >= float(_playlist[_pl_index]["length"]):
			_pl_started += float(_playlist[_pl_index]["length"])
			_pl_index = (_pl_index + 1) % _playlist.size()
	return [_pl_index, clampf(_clock - _pl_started, 0.0, float(_playlist[_pl_index]["length"]) - 0.5)]


## Le morceau écouté est vraiment fini : on passe au suivant.
func _on_track_finished() -> void:
	if not _is_playlist(_loaded) or _playlist.is_empty():
		return
	_pl_index = (_pl_index + 1) % _playlist.size()
	_pl_started = _clock
	# relancé hors du signal de fin du haut-parleur 0 : lancé depuis son propre signal,
	# il repartait un bloc audio (~10 ms) avant les trois autres
	_load.call_deferred(_loaded)


## Titre du morceau en cours (vide si la station n'est pas une playlist).
func get_track_title() -> String:
	if not _is_playlist(station) or _playlist.is_empty():
		return ""
	return _playlist[_playlist_now()[0]]["title"]


static func _prepare_loop(w: AudioStreamWAV) -> void:
	if w == null:
		return
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.get_length() * w.mix_rate)


func is_on() -> bool:
	var level: int = car.get_ignition_level() if car and car.has_method("get_ignition_level") else 2
	return power and level >= 1


# --- Commandes -------------------------------------------------------------------

func set_station(i: int) -> void:
	station = posmod(i, STATIONS.size())
	_tuning = 0.35   # petit grésillement le temps de « trouver » la station


func next_station() -> void:
	set_station(station + 1)


func prev_station() -> void:
	set_station(station - 1)


func toggle_power() -> void:
	power = not power


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_show_vol = 1.5
	_apply_knob()


func _apply_knob() -> void:
	if _knob:
		var a := deg_to_rad(-KNOB_SWEEP_DEG * 0.5 + KNOB_SWEEP_DEG * volume)
		_knob.transform.basis = Basis(Vector3.BACK, -a)


func _press(kind: String) -> void:
	if not _buttons.has(kind):
		return
	var m: Node3D = _buttons[kind][0]
	var tw := create_tween()
	tw.tween_property(m, "position", Vector3(0, 0, -0.0022), 0.05)
	tw.tween_property(m, "position", Vector3.ZERO, 0.1)
	if kind == "power":
		toggle_power()   # marche même contact coupé : elle se rallumera avec le contact
		return
	if not is_on():
		return
	match kind:
		"prev": prev_station()
		"next": next_station()
		_:
			if kind.begins_with("p"):
				set_station(int(kind.substr(1)))


# --- Saisie ----------------------------------------------------------------------

var _grab_ref := Vector3.ZERO
var _grab_vol := 0.0
var _last_local := Vector3.ZERO


func _grip_begin(kind: String, hand: Node3D) -> void:
	if kind == "knob":
		_grab_ref = _twist_ref(hand)
		_grab_vol = volume
		_last_local = to_local(hand.global_position)
	else:
		_press(kind)


func _grip_update(kind: String, hand: Node3D) -> void:
	if kind != "knob":
		return
	if hand.is_in_group("mouse_hands"):
		# souris : glisser vers la droite = monter le volume
		var local := to_local(hand.global_position)
		set_volume(volume + ((local - _last_local).x + (local - _last_local).y) / 0.08)
		_last_local = local
	else:
		var ref := _twist_ref(hand)
		var d := atan2(_grab_ref.cross(ref).z, _grab_ref.dot(ref))
		set_volume(_grab_vol - d / deg_to_rad(KNOB_SWEEP_DEG))   # sens horaire = plus fort


func _grip_end(_kind: String, _hand: Node3D) -> void:
	pass


func _grip_toggle(kind: String) -> void:
	if kind == "knob":
		toggle_power()
	else:
		_press(kind)


func _twist_ref(hand: Node3D) -> Vector3:
	var v := global_basis.orthonormalized().inverse() * hand.global_basis.x
	v.z = 0.0
	return v.normalized() if v.length_squared() > 1e-4 else Vector3.RIGHT


# --- Touches au doigt (VR) ----------------------------------------------------------
# On appuie sur une touche avec le bout de l'index, sans bouton de manette : le doigt
# arrive sur la face de la touche (repère de la radio : +Z vers le conducteur) ; il faut
# le retirer d'un centimètre pour pouvoir rappuyer.

var _finger_on := {}            # [main, touche] -> vrai tant que le doigt appuie


func _update_finger_presses() -> void:
	for hand in get_tree().get_nodes_in_group(VRHandInteractor.TOUCH_GROUP):
		var ok: bool = hand.can_touch()
		var tip: Vector3 = to_local(hand.fingertip_position()) if ok else Vector3.ZERO
		for kind in _buttons:
			var key := [hand, kind]
			if not ok:
				_finger_on.erase(key)
				continue
			var m: Node3D = _buttons[kind][0]
			var g := m.get_parent() as Node3D
			var ab := AABB(Vector3(-0.008, -0.006, -0.004), Vector3(0.016, 0.012, 0.008))
			if m is MeshInstance3D and (m as MeshInstance3D).mesh:
				ab = (m as MeshInstance3D).get_aabb()
			var c := g.position + ab.get_center()
			var half := ab.size * 0.5
			var face := g.position.z + ab.end.z
			var on: bool = _finger_on.has(key)
			var slack := 0.006 if on else 0.002
			var inside := absf(tip.x - c.x) < half.x + slack and absf(tip.y - c.y) < half.y + slack
			if on:
				if not inside or tip.z > face + 0.01:
					_finger_on.erase(key)
			elif inside and tip.z < face + 0.004 and tip.z > face - 0.025:
				_finger_on[key] = true
				_press(kind)
				hand.pulse(0.3, 0.03)


# --- Partie à deux ------------------------------------------------------------------

## Conducteur : où en est la radio (horloge des stations, playlist, morceau et position
## dans les haut-parleurs).
func net_state() -> Array:
	var pos := -1.0
	if not speakers.is_empty() and speakers[0].playing:
		pos = speakers[0].get_playback_position()
	return [_clock, _pl_index, _pl_started, _offsets.duplicate(), _loaded, _track, pos]


## Copilote : se cale sur la radio du conducteur (même morceau, même position, à
## `latency` s près, le temps que le message arrive). Chaque machine tirait son
## morceau et sa position, et dérivait ensuite : la musique n'était pas la même.
func net_apply(st: Array, latency: float) -> void:
	if st.size() < 7:
		return
	_clock = float(st[0]) + latency
	_pl_index = st[1]
	_pl_started = st[2]
	var offs: Array = st[3]
	if offs.size() == _offsets.size():
		_offsets.assign(offs)
	var loaded: int = st[4]
	if loaded != _loaded or loaded < 0:
		return   # station ou marche différente : la main de l'autre joueur arrive
	if _track != int(st[5]):
		_load(_loaded)   # pas le même morceau de la playlist : relancé au bon endroit
		return
	var pos: float = st[6]
	if pos < 0.0 or speakers.is_empty() or not speakers[0].playing:
		return
	var target := pos + latency
	var length := speakers[0].stream.get_length() if speakers[0].stream else 0.0
	if length > 0.0:
		target = fmod(target, length)
	if absf(speakers[0].get_playback_position() - target) > 0.12:
		for p in speakers:
			p.seek(target)


# --- Mise à jour -----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_update_decoding()
	_update_finger_presses()
	_show_vol = maxf(_show_vol - delta, 0.0)
	_tuning = maxf(_tuning - delta, 0.0)
	var on := is_on()
	var want := -2
	if on:
		want = -1 if _tuning > 0.0 else station
	if want != _loaded:
		_load(want)   # (playlist : le morceau suivant est lancé par _on_track_finished)
	var db := linear_to_db(maxf(pow(volume, 1.6), 0.0001)) + max_volume_db
	if _is_playlist(want):
		db += playlist_gain_db
	for p in speakers:
		p.volume_db = db if want != -1 else db - 6.0
	# lueur la nuit (proportionnelle à l'obscurité), seulement radio allumée
	var dark := 0.0
	var w = car.get_weather() if car and car.has_method("get_weather") else null
	if w:
		dark = w.get_darkness()
	var target := dark if on else 0.0
	_glow_level = move_toward(_glow_level, target, delta * 4.0)
	_glow.visible = _glow_level > 0.02
	_glow.light_energy = screen_glow_energy * _glow_level
	# écran
	_freq_lbl.visible = on
	_name_lbl.visible = on
	if on:
		var s: Dictionary = STATIONS[station]
		_freq_lbl.text = ("%s FM" % s["freq"]) if _tuning <= 0.0 else "%s ..." % s["freq"]
		if _show_vol > 0.0:
			var n := int(round(volume * 10.0))
			_name_lbl.text = "VOL " + "|".repeat(n) + ".".repeat(10 - n)
		else:
			_name_lbl.text = s["name"] if _tuning <= 0.0 else "RECHERCHE"
			if _tuning <= 0.0 and _is_playlist(station):
				_name_lbl.text = _playlist_screen(s["name"])


## Écran de la playlist : nom de la station 2,5 s, puis titre du morceau (défilant
## s'il est trop long), en boucle.
func _playlist_screen(station_name: String) -> String:
	if _playlist.is_empty():
		return "PLAYLIST VIDE"
	var t := fmod(_clock, 9.0)
	if t < 2.5:
		return station_name
	var title := get_track_title().to_upper()
	if title.length() <= TITLE_CHARS:
		return title
	var loop := title + "   ·   "
	var start := int((t - 2.5) * 3.0) % loop.length()
	return (loop + loop).substr(start, TITLE_CHARS)


func _load(what: int) -> void:
	_loaded = what
	_track = -1   # la playlist n'est plus dans les haut-parleurs : elle tourne seule
	for p in speakers:
		p.stop()
	if what == -2:
		return
	var stream: AudioStream = _static if what == -1 else _streams[what]
	var pos := 0.0
	if _is_playlist(what):
		var now := _playlist_now()
		if now[0] < 0 or not _decoded.has(now[0]):
			stream = _static   # dossier vide, ou morceau pas encore décodé : grésillement
		else:
			_track = now[0]
			stream = _decoded[_track]
			pos = now[1]
	elif what >= 0 and stream:
		pos = fmod(_clock + _offsets[what], stream.get_length())   # la station continuait
	if stream == null:
		return
	for p in speakers:
		p.stream = stream
		p.play(pos)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F2: Net.perform(self, &"_press", ["prev"])
		KEY_F3: Net.perform(self, &"_press", ["next"])
		KEY_F4: Net.perform(self, &"toggle_power")
		KEY_F9: Net.perform(self, &"set_volume", [volume - 0.1])
		KEY_F10: Net.perform(self, &"set_volume", [volume + 0.1])
