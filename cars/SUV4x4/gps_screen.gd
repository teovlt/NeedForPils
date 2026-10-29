extends Node3D
## Écran du GPS : la vraie route autour de la voiture, vue de dessus et tournée dans le
## sens de la marche (flèche de la voiture en bas de l'écran), zoom qui s'élargit avec
## la vitesse, prochain virage en haut (« ↰ 250 m »), vitesse et heure en bas, police et
## concurrents en points sur la carte. Allumé avec le contact (écran de démarrage),
## couleurs de nuit quand il fait sombre. Livraison en cours (DeliveryManager) : point
## rose sur la carte (au bord de l'écran si elle est plus loin) et encadré avec la
## distance par la route, le côté et le nombre de sachets.
##
## La carte est dessinée en 2D dans un SubViewport (rafraîchi `refresh_rate` fois par
## seconde) affiché sur un rectangle posé sur la vitre du modèle (gps.glb, face +Z).

const SIZE := Vector2i(400, 240)
## Rectangle de l'écran dans le repère du modèle (devant la fausse carte du modèle).
const SCREEN_SIZE := Vector2(0.1115, 0.0675)
const SCREEN_POS := Vector3(0.0, 0.002, 0.0137)
## Position de la voiture sur l'écran (pixels).
const CAR_PX := Vector2(200, 172)
const BOOT_TIME := 1.6

@export var refresh_rate := 15.0
## Distance visible devant la voiture (m) à l'arrêt et à haute vitesse.
@export var view_ahead := Vector2(110.0, 380.0)
## Un virage est annoncé si la route tourne d'au moins ce nombre de degrés sur 100 m
## (les virages de la route font au plus ~45° sur 100 m).
@export var turn_angle_deg := 30.0
@export var announce_range := 900.0

var _viewport: SubViewport
var _map: Control
var _timer := 0.0
var _on := false
var _boot := 0.0
var _mpp := 0.7               # mètres par pixel (lissé)
var _t := 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_map = Control.new()
	_map.size = SIZE
	_map.draw.connect(_draw_map)
	_viewport.add_child(_map)
	var quad := MeshInstance3D.new()
	quad.name = "Display"
	var qm := QuadMesh.new()
	qm.size = SCREEN_SIZE
	quad.mesh = qm
	quad.position = SCREEN_POS
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.set_meta("_vr_outline", true)   # pas de contour de saisie sur l'image
	add_child(quad)


func _process(delta: float) -> void:
	_t += delta
	var car := _car()
	var on: bool = car != null and car.has_method("get_ignition_level") and car.get_ignition_level() >= 1
	if on and not _on:
		_boot = BOOT_TIME
	_on = on
	_boot = maxf(_boot - delta, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0 / refresh_rate
		_map.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _car() -> Node3D:
	return get_tree().get_first_node_in_group(SUV4x4.GROUP) as Node3D


func _road() -> RoadGenerator:
	return get_tree().get_first_node_in_group("road_generator") as RoadGenerator


# --- Dessin --------------------------------------------------------------------------

func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	if not _on:
		_map.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.02, 0.025))
		return
	var night := _is_night()
	var bg := Color(0.11, 0.13, 0.16) if night else Color(0.86, 0.89, 0.82)
	_map.draw_rect(Rect2(Vector2.ZERO, SIZE), bg)
	if _boot > 0.0:
		var a := clampf(_boot / 0.4, 0.0, 1.0) if _boot < 0.4 else 1.0
		_map.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.05, 0.07, 0.1, a))
		_map.draw_string(font, Vector2(0, 112), "ROUTE LIBRE", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 40, Color(1.0, 0.72, 0.1, a))
		_map.draw_string(font, Vector2(0, 148), "navigation", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 20, Color(0.8, 0.85, 0.9, a))
		var w := (1.0 - _boot / BOOT_TIME) * 200.0
		_map.draw_rect(Rect2(100, 172, w, 6), Color(0.35, 0.7, 1.0, a))
		return
	var car := _car()
	var road := _road()
	if car == null or road == null:
		return
	var kmh := absf(float(car.get("forward_speed"))) * 3.6
	var ahead := lerpf(view_ahead.x, view_ahead.y, clampf(kmh / 130.0, 0.0, 1.0))
	_mpp = lerpf(_mpp, ahead / CAR_PX.y, 0.15)
	var here := road.sample_road(car.global_position)
	if not here["found"]:
		_draw_bars(font, kmh, "Recherche du signal...", 0, night)
		return
	var s: float = here["s"]
	var pts := road.centerline(s - ahead * 0.6, s + ahead * 1.8, maxf(2.0, _mpp * 3.0))
	var inv := car.global_transform.affine_inverse()
	var screen := PackedVector2Array()
	var ahead_from := -1
	for p in pts:
		var l := inv * p
		screen.append(CAR_PX + Vector2(-l.x, -l.z) / _mpp)
		if ahead_from < 0 and l.z > 0.0:
			ahead_from = screen.size() - 1
	# route : bordure, chaussée, puis l'itinéraire (devant nous) en bleu
	var road_px := maxf(road.road_half_width * 2.0 / _mpp, 7.0)
	if screen.size() >= 2:
		_map.draw_polyline(screen, Color(0.55, 0.57, 0.6) if night else Color(0.62, 0.64, 0.6), road_px + 4.0, true)
		_map.draw_polyline(screen, Color(0.3, 0.32, 0.36) if night else Color(1, 1, 1), road_px, true)
		if ahead_from >= 0 and screen.size() - ahead_from >= 2:
			var route := screen.slice(maxi(ahead_from - 1, 0))
			route[0] = CAR_PX
			_map.draw_polyline(route, Color(0.25, 0.62, 1.0), maxf(road_px * 0.45, 4.0), true)
	_draw_blips(car, inv)
	_draw_car_arrow()
	var turn := _next_turn(s)
	var text := "Tout droit"
	if turn[0] != 0:
		text = "%s   virage à %s" % [_fmt_dist(turn[1]), "gauche" if turn[0] < 0 else "droite"]
	_draw_bars(font, kmh, text, turn[0], night)
	_draw_delivery(font, inv)


## Livraison en cours : repère sur la carte et encadré « LIVRAISON 650 m ».
func _draw_delivery(font: Font, inv: Transform3D) -> void:
	var dm := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	if dm == null:
		return
	var info := dm.gps_info()
	if info.is_empty():
		return
	var pink := Color(1.0, 0.25, 0.7)
	# encadré en bas à gauche, au-dessus du bandeau de la vitesse
	var dist := float(info["dist"])
	var txt := "LIVRAISON  "
	if dist > 15.0:
		txt += _fmt_dist(dist)
	elif dist > -15.0:
		txt += "ICI"
	else:
		txt += "DERRIÈRE"
	var detail := ""
	if info["place"] != "route":
		detail = {"station": "station-service", "motel": "motel", "superette": "supérette", "aire": "aire de repos", "camp": "camp"}.get(info["place"], "")
	else:
		detail = ("boîte aux lettres" if info["kind"] == "mailbox" else "carton") + (" à gauche" if float(info["side"]) < 0.0 else " à droite")
	if int(info["left"]) > 1:
		detail += "  ·  x%d" % int(info["left"])
	var r := Rect2(6, SIZE.y - 40 - 50, 178, 46)
	_map.draw_rect(r, Color(0.12, 0.02, 0.08, 0.82))
	_map.draw_rect(Rect2(r.position, Vector2(6, r.size.y)), pink)
	_map.draw_string(font, r.position + Vector2(12, 20), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14, 18, pink.lightened(0.35))
	_map.draw_string(font, r.position + Vector2(12, 39), detail, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14, 14, Color(1, 1, 1, 0.9))
	# repère sur la carte (au bord de l'écran si l'adresse est plus loin)
	if info["pos"] == null:
		return
	var blink := fmod(_t * 2.0, 1.0) < 0.7
	var l := inv * (info["pos"] as Vector3)
	var p := CAR_PX + Vector2(-l.x, -l.z) / _mpp
	var inside := Rect2(Vector2(10, 70), Vector2(SIZE) - Vector2(20, 116)).has_point(p)
	if inside:
		# épingle : goutte rose et petit colis blanc
		_map.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-7, -12), p + Vector2(7, -12)]), pink.darkened(0.2))
		_map.draw_circle(p + Vector2(0, -17), 11.0, Color(0, 0, 0, 0.45))
		_map.draw_circle(p + Vector2(0, -17), 9.0, pink if blink else pink.lightened(0.3))
		_map.draw_rect(Rect2(p + Vector2(-4.5, -21.5), Vector2(9, 9)), Color(1, 1, 1))
		_map.draw_line(p + Vector2(0, -21.5), p + Vector2(0, -12.5), pink, 1.5)
	else:
		p = p.clamp(Vector2(10, 54), Vector2(SIZE) - Vector2(10, 48))
		_map.draw_circle(p, 7.0, Color(0, 0, 0, 0.5))
		_map.draw_circle(p, 5.5, pink)


## Police (rouge et bleu qui clignotent) et camping-car des concurrents (orange).
func _draw_blips(car: Node3D, inv: Transform3D) -> void:
	var pol := get_tree().get_first_node_in_group(Pursuer.GROUP) as Pursuer
	if pol and pol.get("_visual") and (pol.get("_visual") as Node3D).visible:
		var c := Color(1.0, 0.15, 0.15) if fmod(_t * 3.0, 1.0) < 0.5 else Color(0.2, 0.4, 1.0)
		_blip(inv * pol.get_car_position(), c)
	for r in get_tree().get_nodes_in_group(Rivals.GROUP):
		if r.get("_visual") and (r.get("_visual") as Node3D).visible:
			_blip(inv * (r as Node).call("get_car_position"), Color(1.0, 0.55, 0.1))


func _blip(local: Vector3, c: Color) -> void:
	var p := CAR_PX + Vector2(-local.x, -local.z) / _mpp
	p = p.clamp(Vector2(8, 40), Vector2(SIZE) - Vector2(8, 40))   # hors champ : au bord
	_map.draw_circle(p, 8.0, Color(0, 0, 0, 0.5))
	_map.draw_circle(p, 6.0, c)


func _draw_car_arrow() -> void:
	var tip := CAR_PX + Vector2(0, -15)
	var pts := PackedVector2Array([tip, CAR_PX + Vector2(11, 11), CAR_PX + Vector2(0, 5), CAR_PX + Vector2(-11, 11)])
	_map.draw_colored_polygon(pts, Color(1, 1, 1))
	var inner := PackedVector2Array([tip + Vector2(0, 4), CAR_PX + Vector2(8, 8), CAR_PX + Vector2(0, 3), CAR_PX + Vector2(-8, 8)])
	_map.draw_colored_polygon(inner, Color(0.1, 0.45, 0.95))


## Bandeau du haut (prochain virage) et du bas (vitesse, heure).
func _draw_bars(font: Font, kmh: float, text: String, turn: int, night: bool) -> void:
	var bar := Color(0.06, 0.08, 0.12, 0.92) if night else Color(0.13, 0.32, 0.55, 0.95)
	_map.draw_rect(Rect2(0, 0, SIZE.x, 46), bar)
	_draw_turn_arrow(Vector2(28, 23), turn)
	_map.draw_string(font, Vector2(56, 34), text, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 60, 30, Color(1, 1, 1))
	_map.draw_rect(Rect2(0, SIZE.y - 40, SIZE.x, 40), Color(0, 0, 0, 0.55))
	_map.draw_string(font, Vector2(10, SIZE.y - 10), "%d km/h" % roundi(kmh), HORIZONTAL_ALIGNMENT_LEFT, 180, 28, Color(1, 1, 1))
	var w := get_tree().get_first_node_in_group(WeatherSystem.GROUP) as WeatherSystem
	if w:
		_map.draw_string(font, Vector2(SIZE.x - 170, SIZE.y - 10), w.get_time_string(), HORIZONTAL_ALIGNMENT_RIGHT, 160, 28, Color(1, 1, 1))


## Flèche du bandeau : tout droit (0), à gauche (-1), à droite (+1).
func _draw_turn_arrow(c: Vector2, turn: int) -> void:
	var col := Color(1, 1, 1)
	var stem_top := c + Vector2(0, -2) if turn != 0 else c + Vector2(0, -8)
	_map.draw_line(c + Vector2(0, 14), stem_top, col, 5.0)
	var head: Vector2
	var dir: Vector2
	if turn == 0:
		head = c + Vector2(0, -15)
		dir = Vector2.UP
	else:
		var end := stem_top + Vector2(12 * turn, -8)
		_map.draw_line(stem_top, end, col, 5.0)
		head = end + Vector2(6 * turn, -4)
		dir = Vector2(turn, -0.66).normalized()
	var side := Vector2(-dir.y, dir.x)
	_map.draw_colored_polygon(PackedVector2Array([head, head - dir * 11 + side * 8, head - dir * 11 - side * 8]), col)


## Prochain virage marqué devant la voiture (abscisse `s`) :
## [-1 gauche / +1 droite / 0 aucun, distance].
func _next_turn(s: float) -> Array:
	var line := _road().centerline(s, s + announce_range, 5.0)
	var span := 20   # 100 m
	if line.size() < span + 3:
		return [0, 0.0]
	var dist := 0.0
	for i in range(1, line.size() - span - 1):
		dist += line[i].distance_to(line[i - 1])
		var d0 := line[i] - line[i - 1]
		var d1 := line[i + span] - line[i + span - 1]
		var a := Vector2(d0.x, d0.z).angle_to(Vector2(d1.x, d1.z))
		if absf(a) > deg_to_rad(turn_angle_deg):
			# dans le plan (x, z) de la voiture (+Z devant, +X à gauche), tourner à gauche
			# fait passer la direction de +Z vers +X : angle négatif
			return [-1 if a < 0.0 else 1, dist]
	return [0, 0.0]


func _fmt_dist(m: float) -> String:
	if m >= 1000.0:
		return ("%.1f km" % (m / 1000.0)).replace(".", ",")
	return "%d m" % maxi(roundi(m / 10.0) * 10, 10)


func _is_night() -> bool:
	var w := get_tree().get_first_node_in_group(WeatherSystem.GROUP) as WeatherSystem
	return w != null and w.get_darkness() > 0.55
