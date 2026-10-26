class_name ClusterDisplay
extends Node2D
## Dessin du combiné d'instruments (compteur à aiguille, heure, rapport, voyants).
## Pas de météo ni de compteur d'arbres : seulement les infos de conduite.
## Lit l'état du 4x4 (SUV4x4) à chaque image.

const MAX_KMH := 160.0
const BG := Color(0.02, 0.025, 0.035)
const DIAL := Color(0.85, 0.88, 0.92)
const DIM := 0.13   # opacité d'un voyant éteint

var car: Node
var size := Vector2(640, 240)
var _shown_kmh := 0.0
var _blink := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_blink += delta
	if car:
		var kmh := absf(car.forward_speed) * 3.6
		_shown_kmh = lerpf(_shown_kmh, kmh, clampf(delta * 8.0, 0.0, 1.0))
	queue_redraw()


func _text(center_x: float, baseline_y: float, text: String, font_size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(center_x - w * 0.5, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Vu du siège, la jante du volant cache le haut de l'écran (surtout sur les côtés)
	# et les branches cachent le bas : le contenu tient dans une arche au centre.
	_draw_speedometer(Vector2(165, 145), 72.0)
	if car == null:
		return
	_draw_right_panel()


# --- Compteur de vitesse -----------------------------------------------------

func _speed_angle(kmh: float) -> float:
	return deg_to_rad(135.0 + 270.0 * clampf(kmh, 0.0, MAX_KMH) / MAX_KMH)


func _draw_speedometer(c: Vector2, r: float) -> void:
	draw_circle(c, r + 6.0, Color(0.06, 0.07, 0.09))
	draw_arc(c, r + 6.0, 0.0, TAU, 64, Color(0.3, 0.32, 0.36), 2.0, true)
	# zone rouge au-delà de 130 km/h
	draw_arc(c, r - 3.0, _speed_angle(130.0), _speed_angle(MAX_KMH), 24, Color(0.85, 0.15, 0.1), 5.0, true)
	for v in range(0, int(MAX_KMH) + 1, 10):
		var ta := _speed_angle(v)
		var dir := Vector2(cos(ta), sin(ta))
		var major: bool = v % 20 == 0
		var l := 14.0 if major else 7.0
		draw_line(c + dir * (r - l), c + dir * r, DIAL, 3.0 if major else 1.5, true)
		if major:
			var p := c + dir * (r - 26.0)
			_text(p.x, p.y + 6.0, str(v), 15, DIAL)
	# aiguille
	var na := _speed_angle(_shown_kmh)
	var nd := Vector2(cos(na), sin(na))
	var n := Vector2(-nd.y, nd.x)
	var tip := c + nd * (r - 8.0)
	var base := c - nd * 14.0
	draw_colored_polygon(PackedVector2Array([base + n * 4.0, tip + n * 1.0, tip - n * 1.0, base - n * 4.0]), Color(1.0, 0.25, 0.15))
	draw_circle(c, 9.0, Color(0.2, 0.21, 0.24))
	draw_circle(c, 4.0, Color(0.55, 0.56, 0.6))
	# vitesse numérique en bas du cadran
	if car:
		_text(c.x, c.y + 44.0, "%d" % roundi(absf(car.forward_speed) * 3.6), 24, Color.WHITE)
	_text(c.x, c.y + 60.0, "km/h", 12, Color(0.6, 0.63, 0.68))


# --- Partie droite : heure, rapport, voyants ----------------------------------

func _draw_right_panel() -> void:
	var cx := 478.0
	# Heure (au-dessus des rapports : ni sous la jante ni sous la branche du haut)
	var weather = car.get_weather()
	var time_str := "--:--"
	if weather:
		time_str = weather.get_time_string()
	_text(cx - 42.0, 100.0, time_str, 30, Color(0.85, 0.95, 1.0))
	# Rapport engagé
	var gears := ["R", "N", "D", "2", "1"]
	var g: int = car.get_gear()
	for i in gears.size():
		var x := cx - 64.0 + i * 32.0
		var cur := i == g
		if cur:
			draw_rect(Rect2(x - 13.0, 110.0, 26.0, 28.0), Color(0.95, 0.65, 0.1), false, 2.0)
		_text(x, 132.0, gears[i], 22 if cur else 17, Color(1.0, 0.75, 0.2) if cur else Color(0.45, 0.47, 0.5))
	# Voyants
	var lights: Dictionary = car.get_lights_on()
	var hb_on: bool = car.get_handbrake_amount() > 0.3
	var y := 160.0
	_icon_low_beam(Vector2(cx - 92.0, y), Color(0.2, 0.95, 0.35, 1.0 if lights["low"] else DIM))
	if car.get_light_mode() == 1:   # AUTO
		_text(cx - 92.0, y + 24.0, "AUTO", 11, Color(0.2, 0.95, 0.35, 0.9))
	_icon_high_beam(Vector2(cx - 40.0, y), Color(0.25, 0.55, 1.0, 1.0 if lights["high"] else DIM))
	_icon_bar(Vector2(cx + 14.0, y), Color(1.0, 0.7, 0.15, 1.0 if lights["bar"] else DIM))
	_icon_handbrake(Vector2(cx + 74.0, y), Color(1.0, 0.18, 0.12, 1.0 if hb_on else DIM))
	# ceinture non bouclée : fixe à l'arrêt, clignote quand le carillon sonne
	var belt: int = car.get_belt_warning() if car.has_method("get_belt_warning") else 0
	var belt_on := belt == 1 or (belt == 2 and fmod(_blink, 0.7) < 0.42)
	_icon_seatbelt(Vector2(266.0, 172.0), Color(1.0, 0.18, 0.12, 1.0 if belt_on else DIM))


func _icon_low_beam(p: Vector2, c: Color) -> void:
	# lampe (demi-disque) à droite, rayons inclinés vers le bas à gauche
	draw_arc(p + Vector2(6, 0), 11.0, -PI / 2.0, PI / 2.0, 12, c, 3.0, true)
	draw_line(p + Vector2(6, -11), p + Vector2(6, 11), c, 3.0)
	for i in 3:
		var yy := -7.0 + i * 7.0
		draw_line(p + Vector2(1, yy), p + Vector2(-13, yy + 6.0), c, 2.5, true)


func _icon_high_beam(p: Vector2, c: Color) -> void:
	draw_arc(p + Vector2(6, 0), 11.0, -PI / 2.0, PI / 2.0, 12, c, 3.0, true)
	draw_line(p + Vector2(6, -11), p + Vector2(6, 11), c, 3.0)
	for i in 4:
		var yy := -9.0 + i * 6.0
		draw_line(p + Vector2(1, yy), p + Vector2(-14, yy), c, 2.5, true)


func _icon_bar(p: Vector2, c: Color) -> void:
	# barre de toit : 4 lampes alignées + rayons vers le haut
	draw_rect(Rect2(p.x - 18.0, p.y - 2.0, 36.0, 10.0), c, false, 2.0)
	for i in 4:
		var x := p.x - 13.5 + i * 9.0
		draw_rect(Rect2(x - 2.5, p.y + 0.5, 5.0, 5.0), c)
		draw_line(Vector2(x, p.y - 5.0), Vector2(x, p.y - 13.0), c, 2.0)


func _icon_handbrake(p: Vector2, c: Color) -> void:
	draw_arc(p, 11.0, 0.0, TAU, 24, c, 2.5, true)
	draw_arc(p, 16.0, deg_to_rad(120), deg_to_rad(240), 8, c, 2.5, true)
	draw_arc(p, 16.0, deg_to_rad(-60), deg_to_rad(60), 8, c, 2.5, true)
	_text(p.x, p.y + 6.0, "P", 16, c)


func _icon_seatbelt(p: Vector2, c: Color) -> void:
	# personnage assis (tête, buste, cuisses) barré par la ceinture en diagonale
	draw_circle(p + Vector2(-2, -13), 4.5, c)
	draw_line(p + Vector2(-3, -6), p + Vector2(-5, 7), c, 5.0, true)
	draw_line(p + Vector2(-5, 7), p + Vector2(7, 7), c, 4.5, true)
	draw_line(p + Vector2(7, 7), p + Vector2(9, 15), c, 4.0, true)
	draw_line(p + Vector2(6, -8), p + Vector2(-10, 8), c, 2.5, true)
	draw_circle(p + Vector2(-10, 8), 2.5, c)
