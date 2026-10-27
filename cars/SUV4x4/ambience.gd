extends Node
## Bruits d'ambiance de la carte, entendus depuis la voiture.
##
## - Nappes stéréo en boucle selon le milieu traversé (biomes de la route) et l'heure :
##   forêt (oiseaux, feuillage), prairie (alouettes, sauterelles, brise), montagne (vent,
##   cloches de vaches, buse), nuit (grillons, chouette). Moins d'oiseaux sous la pluie.
## - Cris isolés placés en 3D autour de la voiture (merle, mésange, pinson, coucou ;
##   chouette la nuit ; buse et cloches en montagne) : on entend d'où ils viennent et ils
##   restent derrière quand on roule.
## - Tout passe par le bus audio « Ambiance » : vitres et portes fermées, plus faible et
##   étouffé (filtre passe-bas) ; plus on ouvre, plus c'est fort et clair.
## - Souffle du vent par les fenêtres ouvertes, qui monte avec la vitesse.

const DIR := "res://audio/ambience/"
const BEDS := ["forest", "meadow", "mountain", "night"]
const BUS := "Ambiance"

## Niveau des nappes, vitres ouvertes (dB).
@export var bed_db := -6.0
## Atténuation de l'ambiance voiture fermée (dB) et coupure du filtre (Hz).
## (Moins fort qu'avant : à l'arrêt, vitres fermées, on entend encore les oiseaux.)
@export var closed_db := -10.0
@export var closed_cutoff := 2600.0
@export var open_cutoff := 16000.0
## Intervalle entre deux cris d'oiseaux (ou cloches) placés autour de la voiture (s).
@export var call_gap_min := 7.0
@export var call_gap_max := 22.0
## Souffle du vent à pleine vitesse, vitres ouvertes (dB).
@export var wind_db := -3.0

var car: Node3D
## Ouverture de l'habitacle (0 fermé -> 1 grand ouvert), lissée.
var exposure := 0.0

var _beds := {}
var _bed_gain := {}
var _wind: AudioStreamPlayer
var _bus := -1
var _lp: AudioEffectLowPassFilter
var _call_timer := randf_range(4.0, 12.0)
var _calls := {}
var _road: Node
## Nombre de cris joués depuis le lancement (tests).
var calls_played := 0


func _ready() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, "Master")
		_lp = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(_bus, _lp)
	else:
		_lp = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	for b in BEDS:
		var p := AudioStreamPlayer.new()
		p.name = "Bed_" + b
		p.bus = BUS
		p.stream = _loop(load(DIR + b + ".wav"))
		p.volume_db = -80.0
		add_child(p)
		p.play(randf() * p.stream.get_length())   # chaque nappe démarre à un endroit différent
		_beds[b] = p
		_bed_gain[b] = 0.0
	_wind = AudioStreamPlayer.new()
	_wind.name = "WindRush"
	_wind.stream = _loop(load(DIR + "wind_rush.wav"))
	_wind.volume_db = -80.0
	add_child(_wind)
	_wind.play()
	for c in ["great_tit", "blackbird", "chaffinch", "cuckoo", "owl", "buzzard", "cowbell"]:
		_calls[c] = load(DIR + "call_" + c + ".wav")


static func _loop(w: AudioStreamWAV) -> AudioStreamWAV:
	if w:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return w


## Ouverture de l'habitacle : vitres (avant plus que arrière) et portières ouvertes.
func _cabin_opening() -> Array:
	var win := 0.0
	var cranks: Dictionary = car.get("window_cranks") if car.get("window_cranks") != null else {}
	for code in cranks:
		var o: float = cranks[code].opening
		win += o * (0.36 if code.begins_with("F") else 0.2)
	var doors := 0.0
	var dn := car.get_node_or_null("Doors")
	if dn:
		for d in dn.get_children():
			if d.has_method("is_open") and d.is_open():
				doors += 0.7
	return [clampf(win + doors, 0.0, 1.0), clampf(win, 0.0, 1.0)]


func _process(delta: float) -> void:
	if car == null:
		return
	if _road == null:
		_road = get_tree().get_first_node_in_group("road_generator")
	var op := _cabin_opening()
	exposure = move_toward(exposure, op[0], delta * 2.0)
	# l'habitacle filtre et atténue tout ce qui vient de dehors
	var e := sqrt(exposure)
	AudioServer.set_bus_volume_db(_bus, lerpf(closed_db, 0.0, e))
	if _lp:
		_lp.cutoff_hz = lerpf(closed_cutoff, open_cutoff, pow(exposure, 0.7))
	# milieu, heure, météo
	var bw := [0.25, 0.25, 0.5, 0.0]
	if _road and _road.has_method("get_biome_at"):
		bw = _road.get_biome_at(car.global_position)
	var w = car.get_weather() if car.has_method("get_weather") else null
	var dark: float = w.get_darkness() if w else 0.0
	var rain: float = w.rain if w else 0.0
	var forest: float = bw[0] + bw[1] * 0.8
	var meadow: float = bw[2] + bw[1] * 0.2
	var mountain: float = bw[3]
	var birds := (1.0 - dark) * (1.0 - 0.85 * rain)
	var target := {
		"forest": forest * (1.0 - mountain) * birds,
		"meadow": meadow * (1.0 - mountain) * birds,
		"mountain": mountain * (1.0 - 0.4 * dark),
		"night": dark * (1.0 - 0.7 * rain) * (1.0 - 0.5 * mountain),
	}
	for b in BEDS:
		_bed_gain[b] = move_toward(_bed_gain[b], target[b], delta * 0.25)   # transitions douces
		(_beds[b] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_bed_gain[b], 0.0001)) + bed_db
	# souffle du vent par les fenêtres ouvertes
	var speed := absf(float(car.get("forward_speed")))
	var k := clampf(speed / 33.0, 0.0, 1.0)
	var g: float = op[1] * pow(k, 1.6)
	_wind.volume_db = linear_to_db(maxf(g, 0.0001)) + wind_db
	_wind.pitch_scale = 0.75 + 0.5 * k
	# cris isolés autour de la voiture
	_call_timer -= delta
	if _call_timer <= 0.0:
		_call_timer = randf_range(call_gap_min, call_gap_max)
		_spawn_call(forest, meadow, mountain, dark, rain)


func _spawn_call(forest: float, meadow: float, mountain: float, dark: float, rain: float) -> void:
	var call_name := ""
	if dark > 0.6:
		if randf() < 0.35:
			call_name = "owl"
	elif rain < 0.4:
		var r := randf()
		if mountain > 0.4 and r < mountain * 0.7:
			call_name = "cowbell" if randf() < 0.65 else "buzzard"
		elif randf() < forest + meadow * 0.5:
			call_name = ["great_tit", "blackbird", "chaffinch", "blackbird", "cuckoo"][randi() % 5]
	if call_name == "" or _calls.get(call_name) == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _calls[call_name]
	p.bus = BUS
	p.unit_size = 7.0 if call_name != "cowbell" else 10.0
	p.max_distance = 140.0
	p.volume_db = randf_range(-5.0, 0.0)
	p.pitch_scale = randf_range(0.92, 1.1)
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	var ang := randf() * TAU
	var dist := randf_range(14.0, 45.0)
	var root := get_tree().current_scene
	root.add_child(p)
	p.global_position = car.global_position + Vector3(cos(ang) * dist, randf_range(3.0, 9.0), sin(ang) * dist)
	p.finished.connect(p.queue_free)
	p.play()
	calls_played += 1
