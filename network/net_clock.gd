class_name NetClock
extends RefCounted
## Horloge d'un flux de messages de l'autre joueur (voiture, tête et mains...) : donne
## l'instant de son temps de simulation (Net.sim_time) à afficher chez soi, un peu dans
## le passé pour toujours avoir deux messages entre lesquels interpoler.
##
## - Décalage entre les deux horloges : celui du message le moins retardé des dernières
##   secondes (les autres ont attendu dans le Wi-Fi). Il n'est jamais rattrapé d'un coup
##   (la voiture du copilote faisait un bond en avant à chaque paquet arrivé plus vite
##   que les autres) : l'horloge accélère ou ralentit d'au plus SLEW (5 %).
## - Retard d'affichage : suit le retard des messages les plus en retard (gigue du
##   Wi-Fi), entre MIN_DELAY et MAX_DELAY ; plus le réseau est régulier, plus l'autre
##   joueur est montré « en direct ».

const MIN_DELAY := 0.05
const MAX_DELAY := 0.3
## Vitesse maximale de rattrapage de l'horloge (s par s).
const SLEW := 0.05
## Fenêtre (s) sur laquelle on cherche le message le moins retardé.
const WINDOW := 2.0

## Intervalle habituel entre deux messages (s) : marge ajoutée au retard.
var send_interval := 1.0 / 60.0

var _has_sample := false
var _offset := 0.0          # décalage appliqué (lissé) : temps distant - temps local
var _target := 0.0          # décalage visé (message le moins retardé de la fenêtre)
var _win_best := -INF
var _win_start := 0.0
var _late := 0.0            # retard des messages les plus en retard (décroît lentement)
var _delay := 0.1
var _last_local := 0.0


## Un message daté `remote_t` (temps de simulation de l'autre) arrive maintenant.
func sample(remote_t: float, local_t: float) -> void:
	var o := remote_t - local_t
	if not _has_sample or absf(o - _target) > 1.0:
		# premier message, ou l'autre machine a figé longtemps : on repart de zéro
		_has_sample = true
		_offset = o
		_target = o
		_win_best = o
		_win_start = local_t
		_late = 0.0
		_last_local = local_t
		return
	_win_best = maxf(_win_best, o)
	_target = maxf(_target, o)   # message moins retardé : on vise plus haut (sans bond)
	if local_t - _win_start >= WINDOW:
		_target = _win_best   # suit aussi une dérive lente vers le bas
		_win_best = o
		_win_start = local_t
	_late = maxf(_late * 0.98, _target - o)


func is_ready() -> bool:
	return _has_sample


## Instant (temps de l'autre) à afficher, à appeler une fois par image physique.
func render_time(local_t: float) -> float:
	var dt := clampf(local_t - _last_local, 0.0, 0.1)
	_last_local = local_t
	_offset = move_toward(_offset, _target, SLEW * dt)
	var want := clampf(_late * 1.25 + send_interval * 1.5, MIN_DELAY, MAX_DELAY)
	_delay = move_toward(_delay, want, SLEW * dt) if absf(want - _delay) < 0.1 else lerpf(_delay, want, 0.05)
	return local_t + _offset - _delay


func delay() -> float:
	return _delay


## Interpolation générique entre deux valeurs reçues (transformations, vecteurs,
## nombres, tableaux de ces valeurs) ; le reste prend la valeur de `b`.
static func lerp_any(a: Variant, b: Variant, w: float) -> Variant:
	if a == null or b == null or typeof(a) != typeof(b):
		return b if w >= 0.5 or a == null else a
	match typeof(a):
		TYPE_TRANSFORM3D:
			return (a as Transform3D).interpolate_with(b, w)
		TYPE_VECTOR3:
			return (a as Vector3).lerp(b, w)
		TYPE_FLOAT:
			return lerpf(a, b, w)
		TYPE_ARRAY:
			var aa := a as Array
			var ba := b as Array
			if aa.size() != ba.size():
				return b
			var out := []
			out.resize(ba.size())
			for i in ba.size():
				out[i] = lerp_any(aa[i], ba[i], w)
			return out
	return b if w >= 0.5 else a
