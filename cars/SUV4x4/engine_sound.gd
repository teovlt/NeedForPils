class_name EngineSound
extends AudioStreamPlayer3D
## Bruit du moteur du 4x4, généré par code (pas de fichier son).
##
## Régime (tr/min) calculé à partir du rapport engagé et de la vitesse :
## - D : boîte auto à 4 rapports internes qui passent selon le régime et
##   l'accélérateur (on entend les changements de rapport) ;
## - 2 : bloquée sur les 2 premiers rapports, 1 : sur le premier (le moteur
##   tourne plus vite à la même vitesse) ; R : un seul rapport court ;
## - N (ou frein à main serré) : le moteur monte dans les tours avec l'accélérateur.
## Le son : harmoniques de la fréquence d'allumage d'un 4 cylindres
## (régime / 30 Hz), légère saturation selon la charge, souffle d'admission,
## petites irrégularités d'un cylindre à l'autre.

@export var idle_rpm := 800.0
@export var redline_rpm := 5600.0
## tr/min par km/h pour les 4 rapports internes de la boîte auto (D, 2, 1).
@export var gear_rpm_per_kmh := PackedFloat32Array([140.0, 85.0, 55.0, 38.0])
## tr/min par km/h en marche arrière.
@export var reverse_rpm_per_kmh := 160.0
@export var volume := 0.55

var car: Node   # SUV4x4

var rpm := 800.0
var auto_gear := 0          # rapport interne de la boîte auto (0 = 1re)
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
			var top := 3 if gear == 2 else (1 if gear == 3 else 0)
			auto_gear = mini(auto_gear, top)
			# passage des rapports : plus on accélère, plus on monte haut dans les tours
			var shift_up := 2100.0 + 2600.0 * throttle
			if auto_gear < top and kmh * gear_rpm_per_kmh[auto_gear] > shift_up and _shift_timer <= 0.0:
				auto_gear += 1
				_shift_timer = 0.6
			elif auto_gear > 0 and kmh * gear_rpm_per_kmh[auto_gear] < 1250.0 and _shift_timer <= 0.0:
				auto_gear -= 1
				_shift_timer = 0.6
			ratio = gear_rpm_per_kmh[auto_gear]
		# convertisseur de couple : à basse vitesse, le moteur peut tourner plus vite que les roues
		var slip := idle_rpm + throttle * 1900.0 * clampf(1.0 - kmh / 25.0, 0.0, 1.0)
		target = maxf(kmh * ratio, slip)
		target = maxf(target, idle_rpm)
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
		_playback.push_frame(Vector2(out, out))
