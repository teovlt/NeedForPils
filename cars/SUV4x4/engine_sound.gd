class_name EngineSound
extends AudioStreamPlayer3D
## Bruit du moteur du 4x4, généré par code (pas de fichier son).
##
## Régime (tr/min) calculé à partir du rapport engagé et de la vitesse :
## - D : boîte auto à 6 rapports internes, gérée par la voiture (suv_4x4.gd,
##   auto_gear) : on entend les changements de rapport ;
## - 2 : bloquée sur les 2 premiers rapports, 1 : sur le premier (le moteur
##   tourne plus vite à la même vitesse) ; R : un seul rapport court ;
## - N (ou frein à main serré) : le moteur monte dans les tours avec l'accélérateur.
## Le son : harmoniques de la fréquence d'allumage d'un 4 cylindres
## (régime / 30 Hz), légère saturation selon la charge, souffle d'admission,
## petites irrégularités d'un cylindre à l'autre.

@export var idle_rpm := 800.0
@export var redline_rpm := 5600.0
## tr/min par km/h en marche arrière.
@export var reverse_rpm_per_kmh := 160.0
@export var volume := 0.55

var car: Node   # SUV4x4

var rpm := 800.0
var auto_gear := 0          # copie du rapport interne de la voiture (0 = 1re)
var engine_load := 0.0      # charge moteur lissée (0-1)

var _playback: AudioStreamGeneratorPlayback
var _rate := 22050.0
var _phase := 0.0
var _cycle_gain := 1.0
var _noise_lp := 0.0
var _rumble_lp := 0.0
var _shift_timer := 0.0
var _smooth_rpm := 800.0
var _smooth_load := 0.0
var _state := 2            # 0 coupé, 1 démarreur, 2 en marche (lu sur la voiture)
var _was_running := true
var _flare := 0.0          # coup d'accélérateur au démarrage
var _starter_phase := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = 0.12
	stream = gen
	unit_size = 6.0
	max_distance = 120.0
	attenuation_filter_cutoff_hz = 20500.0
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	if car == null:
		return
	_update_rpm(delta)
	_fill_audio()


## Régime cible selon le rapport, la vitesse et l'accélérateur.
func _update_rpm(delta: float) -> void:
	var st = car.get("engine_state")
	_state = 2 if st == null else int(st)
	if _state != 2:
		# coupé : le moteur s'arrête ; démarreur : il est entraîné lentement (~230 tr/min)
		var t0 := 0.0
		if _state == 1:
			t0 = 230.0 + 70.0 * sin(Time.get_ticks_msec() * 0.028)
		_smooth_rpm = lerpf(_smooth_rpm, t0, clampf(delta * (8.0 if _state == 1 else 2.2), 0.0, 1.0))
		rpm = _smooth_rpm
		_smooth_load = 0.0
		engine_load = 0.0
		_was_running = false
		auto_gear = 0
		return
	if not _was_running:
		_was_running = true
		_flare = 1.0   # le moteur prend : petite montée dans les tours puis ralenti
	_flare = maxf(_flare - delta * 1.1, 0.0)
	var kmh := absf(car.forward_speed) * 3.6
	var throttle: float = car.throttle_input
	var gear: int = car.get_gear()   # 0 R, 1 N, 2 D, 3 « 2 », 4 « 1 »
	var hb: float = car.get_handbrake_amount()
	var target := idle_rpm
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	if gear == 1 or hb > 0.3:
		# point mort : on fait monter le moteur dans les tours à vide
		var cap := redline_rpm if gear == 1 else 3200.0
		target = idle_rpm + throttle * (cap - idle_rpm)
	else:
		var ratio: float
		if gear == 0:
			ratio = reverse_rpm_per_kmh
			auto_gear = 0
		else:
			# rapport interne choisi par la boîte auto de la voiture (6 rapports)
			var g: int = car.auto_gear
			if g != auto_gear:
				_shift_timer = 0.6
				auto_gear = g
			var ratios: PackedFloat32Array = car.auto_rpm_per_kmh
			ratio = ratios[auto_gear]
		# convertisseur de couple : à basse vitesse, le moteur peut tourner plus vite que les roues
		var slip := idle_rpm + throttle * 1900.0 * clampf(1.0 - kmh / 25.0, 0.0, 1.0)
		target = maxf(kmh * ratio, slip)
		target = maxf(target, idle_rpm)
	target += 650.0 * _flare * _flare
	target = minf(target, redline_rpm + 150.0 * sin(Time.get_ticks_msec() * 0.06) * float(target > redline_rpm))
	# le régime suit vite en montée, un peu moins vite en descente
	var k := 7.0 if target > _smooth_rpm else 4.5
	if _shift_timer > 0.45:
		k = 14.0   # changement de rapport : chute rapide du régime
	_smooth_rpm = lerpf(_smooth_rpm, target, clampf(delta * k, 0.0, 1.0))
	rpm = _smooth_rpm
	var braking: float = car.brake_input
	_smooth_load = lerpf(_smooth_load, clampf(throttle - braking * 0.5, 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))
	engine_load = _smooth_load


func _fill_audio() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var f := rpm / 30.0                       # fréquence d'allumage (4 cylindres, 4 temps)
	var rpm_n := clampf((rpm - idle_rpm) / (redline_rpm - idle_rpm), 0.0, 1.0)
	var drive := 1.1 + engine_load * 1.8 + rpm_n * 0.6
	var amp := volume * (0.35 + 0.4 * engine_load + 0.25 * rpm_n)
	var hiss := 0.05 + 0.22 * engine_load * (0.3 + rpm_n)
	var step := f / _rate
	var lp_k := clampf(0.08 + rpm_n * 0.25, 0.0, 1.0)
	# moteur qui s'arrête / entraîné par le démarreur : plus faible, sans souffle
	var life := clampf(rpm / idle_rpm, 0.0, 1.0)
	if _state != 2:
		amp *= life * life * (1.6 if _state == 1 else 1.0)
		hiss *= 0.3
	var starter := 0.22 * volume if _state == 1 else 0.0
	var st_step := (310.0 + rpm * 0.25) / _rate
	for i in frames:
		_phase += step
		if _phase >= 1.0:
			_phase -= 1.0
			_cycle_gain = 0.85 + randf() * 0.3   # chaque explosion est un peu différente
		var p := _phase * TAU
		var s := 0.55 * sin(p) + 0.32 * sin(2.0 * p + 0.4) + 0.18 * sin(3.0 * p + 1.3) + 0.1 * sin(5.0 * p + 0.7)
		_rumble_lp += (sin(p * 0.5) - _rumble_lp) * 0.2   # grondement du vilebrequin
		s = s * _cycle_gain + 0.35 * _rumble_lp
		s = tanh(s * drive) / tanh(drive)          # saturation : plus rauque sous charge
		var white := randf() * 2.0 - 1.0
		_noise_lp += (white - _noise_lp) * lp_k    # souffle d'admission / échappement
		var out := (s * 0.8 + _noise_lp * hiss) * amp
		if starter > 0.0:
			# démarreur : sifflement électrique + engrenage qui grince
			_starter_phase = fmod(_starter_phase + st_step, 1.0)
			var sp := _starter_phase * TAU
			out += (0.6 * sin(sp) + 0.3 * sin(2.0 * sp) + 0.25 * (randf() * 2.0 - 1.0)) * starter
		_playback.push_frame(Vector2(out, out))
